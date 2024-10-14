<h1 align="center"> Golem Requestor - Windows Installer </h1>

## Why this installer?
I wrote this installer to make it easier to install/update & manage the Golem Requestor daemon for Windows.
Indeed, initially, you have to:
- Download the latest Yagna binaries.
- Extract them somewhere on your system.
- Add the path to the Path environment variable.
- Create the app-key.
- Request test tokens.  

In addition, you need to first launch the daemon in a dedicated terminal before running your application.  
WinSW is used to wrap Yagna daemon as a Windows service.

**Thus, this tool makes it possible to automate the installation of the daemon.**  
**Once installed, no need to worry about the daemon anymore, it is launched automatically, just start your application.**  
  
## How to use:  
- Download ZIP archive and extract (or clone) this repository somewhere on your system.  
- Click on CreateShortcut.bat to create a shortcut on your desktop.
- Launch GolemRequestorService by clicking on shortcut.
- Select option 1.

<p align="center">
  <img src="resources/icon.png"> 
</p>
  
Additional actions are available to manage the service.  
To update Yagna just relaunch GolemRequestorService and select option 1 as for initial installation.  
  
<p align="center">
<img src="resources/grs.png" width="100%"> 
</p>
