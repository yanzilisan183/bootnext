# bootnext
临时和永久改变UEFI下一次默认启动的操作系统  

因为找到的bootnext在Win10上无法工作，所以借助AI写了bash shell脚本和PowerShell脚本。

### Linux端：
+ 需要调用efibootmgr，请提前安装好；
+ 建议保存路径：/usr/bin/bootnext;

### Windows10端：
+ 需要调用bcdedit;
+ 建议保存路径：%WINDIR%\System32\bootnext.ps1, %WINDIR%\System32\bootnext.cmd

两端命令用法和实现逻辑基本保持一致；  
为了避免字符集问题，全部使用英文；  
使用方法可以执行 bootnext --help 查看；  
