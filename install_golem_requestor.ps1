#powershell.exe -ExecutionPolicy Bypass -File install_golem_requestor.ps1

function Get-Golem-Repository {
	$HomeDirectory = [System.Environment]::GetEnvironmentVariable('USERPROFILE')
    $GolemDirectory = '{0}\golem' -f $HomeDirectory
    Write-Output $GolemDirectory
}

function Check-Path
{
	param (
        $Path
    )

    Write-Output $(Test-Path -path $Path -PathType Any)
}

function Create-Repository {
	param (
        $Directory
    )

    $null = New-Item -ItemType Directory -Force -Path $Directory
}

function Check-Yagna
{
	param (
        $GolemDirectory
    )

    $ExeYagna = '{0}\{1}' -f $GolemDirectory, 'yagna.exe'
	$ExeGftp = '{0}\{1}' -f $GolemDirectory, 'gftp.exe'

	Write-Output ($(Check-Path $ExeYagna) -and $(Check-Path $ExeGftp))
}

function Check-WinSW
{
	param (
        $GolemDirectory
    )

    $ExeWinSW = '{0}/{1}' -f $GolemDirectory, 'WinSW-x64.exe'
	$ConfigWinSW = '{0}/{1}' -f $GolemDirectory, 'WinSW-x64.xml'

	Write-Output ($(Check-Path $ExeWinSW) -and $(Check-Path $ConfigWinSW))
}

function Check-Yagna-And-WinSW
{
	param (
        $GolemDirectory
    )

	if (!$(Check-Yagna $GolemDirectory) -and $(Check-WinSW $GolemDirectory)) {
		Write-Host "Error, your install is not complete, please reinstall" -f Red
		Write-Host
		exit(-1)
	}
}

function Download-WinSW {
	param (
        $WinswUri,
        $GolemDirectory
    )

    $WinswFilename = $WinswUri.Split("/")[-1]
    $WinswTargetPath = '{0}\{1}' -f $GolemDirectory, $WinswFilename
	Invoke-WebRequest -UseBasicParsing $WinswUri -OutFile $WinswTargetPath -ErrorAction Stop 
}

function Download-Yagna {
	param (
        $YagnaLastRelaseUri,
        $GolemDirectory
    )

	$res = Invoke-WebRequest -Method Get -Uri $YagnaLastRelaseUri -MaximumRedirection 0 -ErrorAction SilentlyContinue
	if ($res.StatusCode -eq 302) 
	{
		$last_release_version = $res.Headers.Location.Split("/")[-1]
		$windows_zip_release = 'golem-requestor-windows-{0}.zip' -f $last_release_version
		$windows_release_uri = 'https://github.com/golemfactory/yagna/releases/download/{0}/{1}' -f $last_release_version, $windows_zip_release
		$temp_directory = [System.Environment]::GetEnvironmentVariable('TEMP','User')
		$downloadtargetpath = '{0}\{1}' -f $temp_directory, $windows_zip_release
		Invoke-WebRequest -UseBasicParsing $windows_release_uri -OutFile $downloadtargetpath -ErrorAction Stop
		Expand-Archive -Force -LiteralPath $downloadtargetpath -DestinationPath $GolemDirectory
	} 
}

function Add-Path-Directory {
	param (
        $Directory
    )

    [Environment]::SetEnvironmentVariable(
	    "Path",
	    [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User) + ";" + $Directory,
	    [EnvironmentVariableTarget]::User)
}

function Install-WinSW
{
	param (
        $Directory
    )

    $WinswUri = 'https://github.com/winsw/winsw/releases/download/v2.12.0/WinSW-x64.exe'
	Download-WinSW $WinswUri $Directory
}

function Install-Yagna
{
	param (
        $Directory
    )

	$YagnaLastRelaseUri = 'https://github.com/golemfactory/yagna/releases/latest'
	Download-Yagna $YagnaLastRelaseUri $Directory
}

function Run-WinSW-Command
{
	param (
		$ExeWinSW,
		$ConfigWinSW,
        $Command
    )

    $WinSWCommand = '{0} {1} {2}' -f $ExeWinSW, $Command, $ConfigWinSW
	Write-Output $(Invoke-Expression $WinSWCommand)
}

function Create-App-Key
{
	param (
		$AppKey
    )

    $AppKey = $(yagna app-key create $AppKey --json) | Out-String
	Write-Output $JsonAppKey
}

function Get-App-Key
{
	$AppKeys = $(yagna app-key list --json) | Out-String
	$JsonAppKeys = ConvertFrom-JSON -InputObject $AppKeys
	Write-Output $JsonAppKeys
}

function Install-All
{
	param (
        $GolemDirectory,
        $ExeWinSW,
    	$ConfigWinSW
    )

    Write-Host "	Create Golem directory if doesn't exist"
	if (!$(Check-Path $GolemDirectory)) {
		Create-Repository $GolemDirectory
		Write-Host "	Golem directory created with success"
	} else {
		Write-Host "	Golem directory already exists"
	}

	Write-Host

	Write-Host "	Download and Install WinSW if not already done"
	if (!$(Check-WinSW $GolemDirectory)) {
		Install-WinSW $GolemDirectory
		Write-Host "	WinSW installed with success"
	} else {
		Write-Host "	WinSW already installed"
	}

	Write-Host

	Write-Host "	Copy service config if not already done"
	$TargetXmlConfig = '{0}\WinSW-x64.xml' -f $GolemDirectory
	if (!$(Check-Path $TargetXmlConfig)) {
		Copy-Item -Path "./WinSW-x64.xml" -Destination $GolemDirectory
		Write-Host "	Service config copied to Golem directory with success"
	} else {
		Write-Host "	Service config already exists in Golem directory"
	}

	Write-Host

	Write-Host "	Stop service if started before updating Yagna"
	$WinSwStatus = Run-WinSW-Command $ExeWinSW $ConfigWinSW 'status'
	if ($WinSwStatus.Contains('Started')) {
		Run-WinSW-Command $ExeWinSW $ConfigWinSW 'stop'
		Write-Host "	Service stopped with success"	
	} elseif ($WinSwStatus.Contains('Stopped')) {
		Write-Host "	Nothing to do, service is stopped"		
	} else {
		Write-Host "	Nothing to do, service is not installed"
	}

	Write-Host

	Write-Host "	Download and Install latest release of Yagna"
	Install-Yagna $GolemDirectory
	Write-Host "	Yagna installed with success"

	Write-Host

	Write-Host "	Add Golem directory to env Path (user) if not already done"
	$EnvPath = $([Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User))
	if (!($EnvPath.Contains($GolemDirectory))) {
		Add-Path-Directory $GolemDirectory
		Write-Host "	Golem directory added to env Path (user) with success"
	} else {
		Write-Host "	Golem directory already in env Path (user)"
	}

	Write-Host

	Write-Host "	Install and start service"

	$WinSwStatus = Run-WinSW-Command $ExeWinSW $ConfigWinSW 'status'
	if ($WinSwStatus.Contains('Stopped')) {
		Write-Host "	Service already exists"		
	} else {
		Run-WinSW-Command $ExeWinSW $ConfigWinSW 'install'
		Write-Host "	Service installed with success"
	}

	Run-WinSW-Command $ExeWinSW $ConfigWinSW 'start'
	Write-Host "	Service started with success"

	$($env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User"))

	Write-Host

	Write-Host "	Create App-Key if not already exist and set env YAGNA_APP_KEY"
	$JsonAppKeys = Get-App-Key
	if (!($JsonAppKeys.Count -eq 0)) {
		$JsonAppKey = $JsonAppKeys[0].key
		$Msg = "	App-key {0} found" -f $JsonAppKeys[0].name
		Write-Host $Msg
	} else {
		$JsonAppKey = $(Create-App-Key "my_app_key")
		Write-Host "	No App-key found, my_app_key created with success"
	}

	[Environment]::SetEnvironmentVariable("YAGNA_APPKEY", $JsonAppKey, [EnvironmentVariableTarget]::User)

	Start-Sleep -Seconds 2

	$($env:YAGNA_APPKEY = [System.Environment]::GetEnvironmentVariable("YAGNA_APPKEY", "User"))
}

function Show-Menu
{
	cls
	Write-Host
	Write-Host "================ Golem Requestor Service Management ================"
	Write-Host
	Write-Host "1: Download and Install/Update All (Yagna, Service, App-key)"
	Write-Host "2: Install service"
	Write-Host "3: Uninstall service"
	Write-Host "4: Start service"
	Write-Host "5: Stop service"
	Write-Host "6: Restart service"
	Write-Host "7: Get service status"
	Write-Host "0: Quit"
	Write-Host
}

function Menu
{
    $GolemDirectory = Get-Golem-Repository
    $ExeWinSW = '{0}/{1}' -f $GolemDirectory, 'WinSW-x64.exe'
    $ConfigWinSW = '{0}/{1}' -f $GolemDirectory, 'WinSW-x64.xml'

	do
	{
		Show-Menu
		$input = Read-Host "Please make a selection"
		Write-Host
		switch ($input)
		{
			'1'
				{
					Write-Host "Download and Install/Update All (Yagna, Service, App-key)"
					Write-Host
					Install-All $GolemDirectory $ExeWinSW $ConfigWinSW
				}
			'2'
				{
					Write-Host "Install service"
					Write-Host
					Check-Yagna-And-WinSW $GolemDirectory
					$WinSwStatus = Run-WinSW-Command $ExeWinSW $ConfigWinSW 'status'
					if (($WinSwStatus.Contains('Started')) -or ($WinSwStatus.Contains('Stopped'))) {
						Write-Host "	Nothing to do, service is already installed"		
					} else {
						Run-WinSW-Command $ExeWinSW $ConfigWinSW 'install'
						Write-Host "	Service installed with success"
					}
				}
			'3'
				{
					Write-Host "Uninstall service"
					Write-Host
					Check-Yagna-And-WinSW $GolemDirectory
					$WinSwStatus = Run-WinSW-Command $ExeWinSW $ConfigWinSW 'status'
					if ($WinSwStatus.Contains('Started')) {
						Run-WinSW-Command $ExeWinSW $ConfigWinSW 'stop'
						Run-WinSW-Command $ExeWinSW $ConfigWinSW 'uninstall'
						Write-Host "	Service stopped and uninstalled with success"		
					} elseif ($WinSwStatus.Contains('Stopped')) {
						Run-WinSW-Command $ExeWinSW $ConfigWinSW 'uninstall'
						Write-Host "	Service uninstalled with success"
					} else {
						Write-Host "	Nothing to do, Service is not installed"
					}
				}
			'4'
				{
					Write-Host "Start service"
					Write-Host
					Check-Yagna-And-WinSW $GolemDirectory
					$WinSwStatus = Run-WinSW-Command $ExeWinSW $ConfigWinSW 'status'
					if ($WinSwStatus.Contains('Started')) {
						Write-Host "	Nothing to do, Service is already started"		
					} elseif ($WinSwStatus.Contains('Stopped')) {
						Run-WinSW-Command $ExeWinSW $ConfigWinSW 'start'
						Write-Host "	Service started with success"
					} else {
						Run-WinSW-Command $ExeWinSW $ConfigWinSW 'install'
						Run-WinSW-Command $ExeWinSW $ConfigWinSW 'start'
						Write-Host "	Service installed and started with success"
					}
				}
			'5'
				{
					Write-Host "Stop service"
					Write-Host
					Check-Yagna-And-WinSW $GolemDirectory
					$WinSwStatus = Run-WinSW-Command $ExeWinSW $ConfigWinSW 'status'
					if ($WinSwStatus.Contains('Started')) {
						Run-WinSW-Command $ExeWinSW $ConfigWinSW 'stop'
						Write-Host "	Service stopped with success"		
					} elseif ($WinSwStatus.Contains('Stopped')) {
						Write-Host "	Nothing to do, Service is already stopped"
					} else {
						Run-WinSW-Command $ExeWinSW $ConfigWinSW 'install'
						Write-Host "	Service is now installed but stopped"
					}
				}
			'6'
				{
					Write-Host "Restart service"
					Write-Host
					Check-Yagna-And-WinSW $GolemDirectory
					$WinSwStatus = Run-WinSW-Command $ExeWinSW $ConfigWinSW 'status'
					if ($WinSwStatus.Contains('Started')) {
						Run-WinSW-Command $ExeWinSW $ConfigWinSW 'restart'
						Write-Host "	Service restarted with success"		
					} elseif ($WinSwStatus.Contains('Stopped')) {
						Write-Host "	Service started with success"
					} else {
						Run-WinSW-Command $ExeWinSW $ConfigWinSW 'install'
						Run-WinSW-Command $ExeWinSW $ConfigWinSW 'start'
						Write-Host "	Service is now installed and started"
					}
				}
			'7'
				{
					Write-Host "Get service status"
					Write-Host
					Check-Yagna-And-WinSW $GolemDirectory
					Run-WinSW-Command $ExeWinSW $ConfigWinSW 'status'
				}
			'0'
				{
					return
				}
		}
		Write-Host
		pause
	}
	until ($input -eq '0')
}

Menu
