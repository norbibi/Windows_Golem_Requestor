# Windows Golem Requestor Installer

I wrote this little Powershell script to make it easier to install & manage the Golem Requestor daemon for Windows.

Indeed, initially, you have to:
- download the latest Yagna binaries on the Golem repository
- extract them somewhere on your system
- add the path to the Path environment variable
- create the app-key
- add this key as an environment variable

And for each use of the network, first launch the daemon in a dedicated window before running your application.  

Thus, this script allows to automate the installation as well as create and manage the daemon as a Windows service.  
As the Yagna daemon does not implement Windows service methods, we use the WinSW binary in order to wrap this binary as a service.

