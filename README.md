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
&nbsp;&nbsp;&nbsp;&nbsp;bootnext <target> [options]  
  
Targets:  
&nbsp;&nbsp;&nbsp;&nbsp;ubuntu          Boot into Ubuntu  
&nbsp;&nbsp;&nbsp;&nbsp;windows         Boot into Windows  
&nbsp;&nbsp;&nbsp;&nbsp;usb             Boot from a USB device  
  
Options:  
&nbsp;&nbsp;&nbsp;&nbsp;-h, --help      Show this help  
&nbsp;&nbsp;&nbsp;&nbsp;-l, --list      List all UEFI boot entries  (-l is lowercase letter L)  
&nbsp;&nbsp;&nbsp;&nbsp;-1, --only-next Set BootNext only, one-shot (-1 is number one)  
&nbsp;&nbsp;&nbsp;&nbsp;-d, --default   Change default BootOrder (default, mutually exclusive with -1)  
&nbsp;&nbsp;&nbsp;&nbsp;-n, --no-reboot Do not reboot (mutually exclusive with -y)  
&nbsp;&nbsp;&nbsp;&nbsp;-y, --reboot    Reboot now    (mutually exclusive with -n)  
  
Examples:  
&nbsp;&nbsp;&nbsp;&nbsp;bootnext ubuntu               # permanent switch to Ubuntu; ask before reboot  
&nbsp;&nbsp;&nbsp;&nbsp;bootnext ubuntu --default     # same as above  
&nbsp;&nbsp;&nbsp;&nbsp;bootnext windows --only-next  # one-shot boot to Windows; ask before reboot  
&nbsp;&nbsp;&nbsp;&nbsp;bootnext ubuntu -1 -n         # one-shot, do not reboot  
&nbsp;&nbsp;&nbsp;&nbsp;bootnext ubuntu -1 -y         # one-shot, reboot immediately  
&nbsp;&nbsp;&nbsp;&nbsp;bootnext --list  
  
或  
bootnext --help

