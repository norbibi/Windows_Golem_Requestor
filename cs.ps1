$DesktopPath = [Environment]::GetFolderPath("Desktop")
$ScriptPath = split-path -parent $MyInvocation.MyCommand.Definition
$ShortcutTarget = '{0}\GolemRequestorService.bat' -f $ScriptPath
$ShortcutFile = '{0}\GolemRequestorService.lnk' -f $DesktopPath
$WScriptShell = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptShell.CreateShortcut($ShortcutFile)
$Shortcut.Arguments = '{0}\grs.ps1' -f $ScriptPath
$Shortcut.TargetPath = $ShortcutTarget
$Shortcut.IconLocation = '{0}\resources\Golem.ico' -f $ScriptPath
$Shortcut.Save()
