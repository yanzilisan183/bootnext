<#
.SYNOPSIS
    bootnext - Switch the next or default UEFI boot entry.
.DESCRIPTION
    Reads UEFI boot entries via bcdedit and sets either BootNext (one-shot)
    or the default BootOrder (permanent).
#>

# ============ Argument parsing ============
$help       = $false
$list       = $false
$noReboot   = $false
$yesReboot  = $false
$onlyNext   = $false
$default    = $false
$command    = $null
$validCmds  = @('ubuntu', 'windows', 'usb')

foreach ($a in $args) {
    $lower = $a.ToLower()
    switch ($lower) {
        '-h'           { $help = $true; continue }
        '--help'       { $help = $true; continue }
        '-l'           { $list = $true; continue }
        '--list'       { $list = $true; continue }
        '-n'           { $noReboot = $true; continue }
        '--no-reboot'  { $noReboot = $true; continue }
        '-y'           { $yesReboot = $true; continue }
        '--reboot'     { $yesReboot = $true; continue }
        '-1'           { $onlyNext = $true; continue }
        '--only-next'  { $onlyNext = $true; continue }
        '-d'           { $default  = $true; continue }
        '--default'    { $default  = $true; continue }
    }
    if ($validCmds -contains $lower) {
        $command = $lower
    } elseif (-not $a.StartsWith('-')) {
        $command = $a
    }
}

if ($onlyNext -and $default) {
    Write-Host 'Error: -1/--only-next and -d/--default are mutually exclusive.' -ForegroundColor Red
    exit 1
}
if ($noReboot -and $yesReboot) {
    Write-Host 'Error: -n/--no-reboot and -y/--reboot are mutually exclusive.' -ForegroundColor Red
    exit 1
}
if (-not $onlyNext -and -not $default) {
    $default = $true
}

# ============ Help ============
function Show-Help {
@"
bootnext - Quickly switch the boot OS.

Usage:
    bootnext <target> [options]

Targets:
    ubuntu          Boot into Ubuntu
    windows         Boot into Windows
    usb             Boot from a USB device

Options:
    -h, --help      Show this help
    -l, --list      List all UEFI boot entries  (-l is lowercase letter L)
    -1, --only-next Set BootNext only, one-shot (-1 is number one)
    -d, --default   Change default BootOrder (default, mutually exclusive with -1)
    -n, --no-reboot Do not reboot (mutually exclusive with -y)
    -y, --reboot    Reboot now    (mutually exclusive with -n)

Examples:
    bootnext ubuntu               # permanent switch to Ubuntu; ask before reboot
    bootnext ubuntu --default     # same as above
    bootnext windows --only-next  # one-shot boot to Windows; ask before reboot
    bootnext ubuntu -1 -n         # one-shot, do not reboot
    bootnext ubuntu -1 -y         # one-shot, reboot immediately
    bootnext --list
"@ | Write-Host
}

# ============ Admin check / self-elevation ============
function Test-Admin {
    $p = New-Object Security.Principal.WindowsPrincipal(
        [Security.Principal.WindowsIdentity]::GetCurrent())
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-Admin)) {
    $quotedArgs = ($args | ForEach-Object {
        if ($_ -match '[\s"]') { '"' + ($_ -replace '"','\"') + '"' } else { $_ }
    }) -join ' '

    $scriptPath = if ($PSCommandPath) { $PSCommandPath } else { $MyInvocation.MyCommand.Path }

    Write-Host 'Administrator privileges required. Requesting elevation...' -ForegroundColor Yellow
    Start-Process -FilePath 'powershell.exe' `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" $quotedArgs" `
        -Verb RunAs
    exit
}

# ============ Read UEFI entries and BootOrder ============
function Get-UefiInfo {
    $raw = & bcdedit /enum firmware 2>&1

    $entries      = @()
    $current      = $null
    $inFw         = $false
    $displayOrder = @()
    $collecting   = $false

    foreach ($line in $raw) {
        $text = "$line".Trim()

        # Identifier line: match both English and Chinese labels
        if ($text -match '^(identifier|\u6807\u8bc6\u7b26)\s+(\{[^}]+\})') {
            if ($current) { $entries += $current }
            $id = $matches[2]
            $inFw = ($id -eq '{fwbootmgr}')
            $collecting = $false

            if ($inFw) {
                $current = $null
            } else {
                $current = [PSCustomObject]@{
                    Identifier  = $id
                    Description = ''
                    Path        = ''
                }
            }
            continue
        }

        if ($inFw) {
            if ($text -match '^displayorder\s+(.+)$') {
                $displayOrder = @($matches[1].Trim() -split '\s+')
                $collecting = $true
                continue
            }
            if ($collecting) {
                if ($text -match '^\{[^}]+\}$') {
                    $displayOrder += $text
                    continue
                } else {
                    $collecting = $false
                }
            }
            continue
        }

        if ($null -eq $current) { continue }
        if ($text -match '^(description|\u63cf\u8ff0)\s+(.+)$') {
            $current.Description = $matches[2].Trim()
        } elseif ($text -match '^path\s+(.+)$') {
            $current.Path = $matches[1].Trim()
        }
    }
    if ($current) { $entries += $current }

    $entries = $entries | Where-Object { $_.Identifier -ne '{fwbootmgr}' }

    return [PSCustomObject]@{
        Entries      = $entries
        DisplayOrder = $displayOrder
    }
}

# ============ Read the current BootNext value ============
function Get-BootNext {
    $raw = & bcdedit /enum '{fwbootmgr}' 2>&1
    foreach ($line in $raw) {
        if ("$line".Trim() -match '^bootsequence\s+(\{[^}]+\})') {
            return $matches[1]
        }
    }
    return $null
}

# ============ Select an entry by patterns ============
function Select-BootEntry {
    param(
        [array]$Entries,
        [string[]]$Patterns
    )
    foreach ($pat in $Patterns) {
        $hit = $Entries | Where-Object { $_.Description -match $pat } | Select-Object -First 1
        if ($hit) { return $hit }
    }
    foreach ($pat in $Patterns) {
        $hit = $Entries | Where-Object { $_.Path -match $pat } | Select-Object -First 1
        if ($hit) { return $hit }
    }
    return $null
}

# ============ Main ============
if ($help -or (-not $command -and -not $list)) {
    Show-Help
    exit 0
}

try {
    $patternMap = @{
        'windows' = @('Windows')
        'ubuntu'  = @('ubuntu')
        'usb'     = @('USB HDD', 'USB CD', 'USB FDD', 'USB', 'Removable')
    }

    $info    = Get-UefiInfo
    $entries = $info.Entries
    $order   = $info.DisplayOrder

    if (-not $entries -or $entries.Count -eq 0) {
        Write-Host 'Cannot read UEFI boot entries. Make sure the system boots in UEFI mode.' -ForegroundColor Red
        exit 1
    }

    if ($list) {
        Write-Host 'UEFI boot entries:' -ForegroundColor Cyan
        $i = 0
        foreach ($e in $entries) {
            $i++
            $desc = if ($e.Description) { $e.Description } else { '(no description)' }
            $path = if ($e.Path)        { $e.Path }        else { '(no path)' }
            Write-Host ("  [{0,2}] {1,-30} {2}" -f $i, $desc, $path)
            Write-Host ("       {0}" -f $e.Identifier) -ForegroundColor DarkGray
        }

        if ($order.Count -gt 0) {
            Write-Host ''
            Write-Host 'Current BootOrder (default priority):' -ForegroundColor Cyan

            $guidWidth = ($entries |
                Where-Object { $_.Identifier -match '^\{[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\}$' } |
                ForEach-Object { $_.Identifier.Length } |
                Measure-Object -Maximum).Maximum
            if (-not $guidWidth) { $guidWidth = 38 }

            $taggedIds = @{}
            foreach ($key in @('windows', 'ubuntu', 'usb')) {
                $hit = Select-BootEntry -Entries $entries -Patterns $patternMap[$key]
                if ($hit) { $taggedIds[$hit.Identifier] = $key }
            }

            foreach ($g in $order) {
                $match = $entries | Where-Object { $_.Identifier -eq $g }
                $name  = if ($match) { $match.Description } else { '(unknown)' }

                Write-Host ("  {0,-$guidWidth}  {1}" -f $g, $name) -NoNewline

                if ($match -and $taggedIds.ContainsKey($match.Identifier)) {
                    Write-Host ('(' + $taggedIds[$match.Identifier] + ')') -ForegroundColor Yellow
                } else {
                    Write-Host ''
                }
            }
        }
        exit 0
    }

    $patterns = if ($patternMap.ContainsKey($command)) { $patternMap[$command] } else { @($command) }

    $target = Select-BootEntry -Entries $entries -Patterns $patterns

    if (-not $target) {
        Write-Host ("No boot entry matches '" + ($patterns -join '|') + "'.") -ForegroundColor Red
        Write-Host 'Use --list to see all available entries.' -ForegroundColor Yellow
        exit 1
    }

    $targetDesc = if ($target.Description) { $target.Description } else { $target.Identifier }

    if ($onlyNext) {
        # -------- One-shot: set BootNext --------
        & bcdedit /set '{fwbootmgr}' bootsequence $target.Identifier | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host 'Failed to set BootNext.' -ForegroundColor Red
            exit 1
        }

        # Self-verify
        $verify = Get-BootNext
        if ($verify -ne $target.Identifier) {
            Write-Host 'Warning: BootNext change could not be verified.' -ForegroundColor Yellow
            exit 1
        }

        # Determine the current permanent default (from BootOrder[0])
        $defaultName = '(unknown)'
        if ($order.Count -gt 0) {
            $defaultEntry = $entries | Where-Object { $_.Identifier -eq $order[0] } | Select-Object -First 1
            if ($defaultEntry -and $defaultEntry.Description) {
                $defaultName = $defaultEntry.Description
            } elseif ($defaultEntry) {
                $defaultName = $defaultEntry.Identifier
            } else {
                $defaultName = $order[0]
            }
        }

        # Colored output: target name in yellow, rest in green.
        Write-Host '[OK] Next reboot use ' -NoNewline -ForegroundColor Green
        Write-Host $targetDesc            -NoNewline -ForegroundColor Yellow
        Write-Host (' (only next), default is {0}.' -f $defaultName) -ForegroundColor Green
    } else {
        # -------- Permanent: set default BootOrder --------
        if ($order.Count -eq 0) {
            Write-Host 'Cannot read current BootOrder; use -1 instead.' -ForegroundColor Red
            exit 1
        }
        $newOrder = @($target.Identifier) + ($order | Where-Object { $_ -ne $target.Identifier })
        $bcdArgs = @('/set', '{fwbootmgr}', 'displayorder') + $newOrder
        & bcdedit @bcdArgs | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host 'Failed to set default BootOrder.' -ForegroundColor Red
            exit 1
        }

        # Self-verify: re-read firmware info and check BootOrder[0]
        $verifyInfo = Get-UefiInfo
        if ($verifyInfo.DisplayOrder.Count -eq 0 -or $verifyInfo.DisplayOrder[0] -ne $target.Identifier) {
            Write-Host 'Warning: BootOrder change could not be verified.' -ForegroundColor Yellow
            exit 1
        }

        # Colored output: target name in yellow, rest in green.
        Write-Host '[OK] Next reboot use ' -NoNewline -ForegroundColor Green
        Write-Host $targetDesc            -NoNewline -ForegroundColor Yellow
        Write-Host ' (permanent).'                   -ForegroundColor Green
    }

    if ($noReboot) {
        exit 0
    }

    if ($yesReboot) {
        Write-Host 'Rebooting...' -ForegroundColor Yellow
        Restart-Computer -Force
        exit 0
    }

    $ans = Read-Host 'Reboot now? (Y/N) [N]'
    if ($ans -match '^[Yy]') {
        Write-Host 'Rebooting...' -ForegroundColor Yellow
        Restart-Computer -Force
    } else {
        Write-Host 'Reboot canceled.' -ForegroundColor Cyan
    }
}
catch {
    Write-Host ("Error: {0}" -f $_.Exception.Message) -ForegroundColor Red
    exit 1
}
