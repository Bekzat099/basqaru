# uninstall_windows.ps1 - removes BASQARU from the PC
Add-Type -AssemblyName System.Windows.Forms
$ErrorActionPreference = 'SilentlyContinue'

$ok = [System.Windows.Forms.MessageBox]::Show('Remove BASQARU from the PC? All game data (saves) will be deleted.', 'BASQARU', 'YesNo', 'Warning')
if ($ok -ne 'Yes') { exit 0 }

# stop service
& (Join-Path $PSScriptRoot 'stop_windows.ps1') | Out-Null
Start-Sleep -Seconds 1

# shortcuts: desktop, start menu, taskbar
$desk = "$env:USERPROFILE\OneDrive\Рабочий стол"
Remove-Item "$desk\BASQARU (играть).lnk" -Force
Remove-Item "$desk\BASQARU (остановить).lnk" -Force
Remove-Item "$desk\Basqaru" -Recurse -Force
Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\BASQARU (играть).lnk" -Force
Remove-Item "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\BASQARU (остановить).lnk" -Force
Remove-Item "$env:APPDATA\Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar\BASQARU (играть).lnk" -Force

# remove from installed programs list
Remove-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\Basqaru' -Recurse -Force

# remove game folder
Remove-Item 'C:\Users\2022\basqaru' -Recurse -Force

[System.Windows.Forms.MessageBox]::Show('BASQARU was removed from the PC.', 'BASQARU')
