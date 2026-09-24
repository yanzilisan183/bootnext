# bootnext
临时和永久改变UEFI下一次默认启动的操作系统  

因为找到的bootnext在Win10上无法工作，所以借助AI写了bash shell脚本和PowerShell脚本。

### Linux端：
+ 需要调用efibootmgr，请提前安装好；
+ 建议保存路径：/usr/bin/bootnext;
+ 请以root或sudo执行，如果你不sudo，会帮你sudo  :D

### Windows10端：
+ 需要调用bcdedit;
+ 建议保存路径：%WINDIR%\System32\bootnext.ps1, %WINDIR%\System32\bootnext.cmd

### 说明
+ 两端命令用法和实现逻辑基本保持一致；  
+ 为了避免字符集问题，全部使用英文；

### 使用方法
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
  
或  
bootnext --help

