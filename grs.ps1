function Get-Golem-Repository {
  $HomeDirectory = [System.Environment]::GetEnvironmentVariable('USERPROFILE')
  $GolemDirectory = '{0}\golem' -f $HomeDirectory
  Write-Output $GolemDirectory
}

function Check-Path {
  param ($Path)
  Write-Output $(Test-Path -path $Path -PathType Any)
}

function Create-Repository {
  param ($Directory)
  $null = New-Item -ItemType Directory -Force -Path $Directory
}

function Check-Yagna {
  param ($GolemDirectory)
  $ExeYagna = '{0}\{1}' -f $GolemDirectory, 'yagna.exe'
  $ExeGftp = '{0}\{1}' -f $GolemDirectory, 'gftp.exe'
  Write-Output ($(Check-Path $ExeYagna) -and $(Check-Path $ExeGftp))
}

function Check-WinSW {
  param ($GolemDirectory)
  $ExeWinSW = '{0}/{1}' -f $GolemDirectory, 'WinSW-x64.exe'
  $ConfigWinSW = '{0}/{1}' -f $GolemDirectory, 'WinSW-x64.xml'
  Write-Output ($(Check-Path $ExeWinSW) -and $(Check-Path $ConfigWinSW))
}

function Check-Yagna-And-WinSW {
  param ($GolemDirectory)
  if (!$(Check-Yagna $GolemDirectory) -and $(Check-WinSW $GolemDirectory)) {
    Write-Host "Error, your install is not complete, please reinstall" -f Red
    Write-Host
    exit(-1)
  }
}

function Download-WinSW {
  param ($WinswUri, $GolemDirectory)
  $WinswFilename = $WinswUri.Split("/")[-1]
  $WinswTargetPath = '{0}\{1}' -f $GolemDirectory, $WinswFilename
  Invoke-WebRequest -UseBasicParsing $WinswUri -OutFile $WinswTargetPath -ErrorAction Stop 
}

function Download-Yagna {
  param ($YagnaLastRelaseUri, $GolemDirectory)
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
  param ($Directory)
  [Environment]::SetEnvironmentVariable(
    "Path",
    [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User) + ";" + $Directory + ";",
    [EnvironmentVariableTarget]::User)
}

function Install-WinSW {
  param ($Directory)
  $WinswUri = 'https://github.com/winsw/winsw/releases/download/v2.12.0/WinSW-x64.exe'
  Download-WinSW $WinswUri $Directory
}

function Install-Yagna {
  param ($Directory)
  $YagnaLastRelaseUri = 'https://github.com/golemfactory/yagna/releases/latest'
  Download-Yagna $YagnaLastRelaseUri $Directory
}

function Run-WinSW-Command {
  param ($ExeWinSW, $ConfigWinSW, $Command)
  $WinSWCommand = '{0} {1} {2}' -f $ExeWinSW, $Command, $ConfigWinSW
  Write-Output $(Invoke-Expression $WinSWCommand)
}

function Create-App-Key {
  param ($GolemDirectory, $AppKey)
  $Cmd = '{0}\yagna.exe app-key create {1} --json' -f $GolemDirectory, $AppKey
  $JsonAppKey = Invoke-Expression $Cmd
  Write-Output $JsonAppKey.Trim('"')
}

function Get-App-Key {
  param ($GolemDirectory)
  $Cmd = '{0}\yagna.exe app-key list --json' -f $GolemDirectory
  $AppKeys = Invoke-Expression $Cmd | Out-String
  $JsonAppKeys = ConvertFrom-JSON -InputObject $AppKeys
  Write-Output $JsonAppKeys
}

function Request-Test-Tokens {
  param ($GolemDirectory)
  $Cmd = '{0}\yagna.exe payment fund' -f $GolemDirectory
  Write-Output $(Invoke-Expression $Cmd)
}

function Install-All {
  param ($GolemDirectory, $ExeWinSW, $ConfigWinSW)

  Write-Host "    Create Golem directory if doesn't exist"
  if (!$(Check-Path $GolemDirectory)) {
    Create-Repository $GolemDirectory
    Write-Host $("    Golem directory {0} created with success" -f $GolemDirectory)
  } else {
    Write-Host $("    Golem directory {0} already exists" -f $GolemDirectory)
  }

  Write-Host
  Write-Host "    Download and Install WinSW if not already done"
  if (!$(Check-WinSW $GolemDirectory)) {
    Install-WinSW $GolemDirectory
    Write-Host "    WinSW installed with success"
  } else {
    Write-Host "    WinSW already installed"
  }

  Write-Host
  Write-Host "    Copy service config"
  $TargetXmlConfig = '{0}\WinSW-x64.xml' -f $GolemDirectory
  if (!$(Check-Path $TargetXmlConfig)) {
    Copy-Item -Path "./WinSW-x64.xml" -Destination $GolemDirectory
    Write-Host "    Service config copied to Golem directory with success"
  } else {
    Write-Host "    Service config already exists in Golem directory"
  }

  Write-Host
  Write-Host "    Stop service before Yagna update"
  $WinSwStatus = Run-WinSW-Command $ExeWinSW $ConfigWinSW 'status'
  if ($WinSwStatus.Contains('Started')) {
    Run-WinSW-Command $ExeWinSW $ConfigWinSW 'stop'
    Write-Host "    Service stopped with success"   
  } elseif ($WinSwStatus.Contains('Stopped')) {
    Write-Host "    Service is already stopped"      
  } else {
    Write-Host "    Service is not installed"
  }

  Write-Host
  Write-Host "    Download and Install latest release of Yagna"
  Install-Yagna $GolemDirectory
  Write-Host "    Yagna installed with success"

  Write-Host
  Write-Host "    Add Golem directory to env Path (user)"
  $EnvPath = $([Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::User))
  if (!($EnvPath.Contains($GolemDirectory))) {
    Add-Path-Directory $GolemDirectory
    Write-Host "    Golem directory added to env Path (user) with success"
  } else {
    Write-Host "    Golem directory already in env Path (user)"
  }

  Write-Host
  Write-Host "    Install and start service"
  $WinSwStatus = Run-WinSW-Command $ExeWinSW $ConfigWinSW 'status'
  if ($WinSwStatus.Contains('Stopped')) {
    Write-Host "    Service already exists"     
  } else {
    Run-WinSW-Command $ExeWinSW $ConfigWinSW 'install'
    Write-Host "    Service installed with success"
  }
  Run-WinSW-Command $ExeWinSW $ConfigWinSW 'start'
  Write-Host "    Service started with success"
  
  Write-Host
  Write-Host "    Create App-Key"
  $JsonAppKeys = $(Get-App-Key $GolemDirectory)
  if (!($JsonAppKeys.Count -eq 0)) {
    $JsonAppKey = $JsonAppKeys[0].key
    Write-Host $("    App-key found")
  } else {
    $JsonAppKey = $(Create-App-Key $GolemDirectory "my_app_key")
    Write-Host "    App-key created with success"
  }

  Start-Sleep -Seconds 5

  Write-Host
  Write-Host "    Request test tokens"
  Request-Test-Tokens $GolemDirectory
}

function Show-Menu {
  cls
  Write-Host
  Write-Host "  ================ Golem Requestor Service Management ================"
  Write-Host
  Write-Host "    1: Install/Update Yagna, Service, App-key, Test tokens"
  Write-Host "    2: Install service"
  Write-Host "    3: Uninstall service"
  Write-Host "    4: Start service"
  Write-Host "    5: Stop service"
  Write-Host "    6: Restart service"
  Write-Host "    7: Get service status"
  Write-Host "    8: Request test tokens"
  Write-Host "    0: Quit"
  Write-Host
}

function Menu {
  $GolemDirectory = Get-Golem-Repository
  $ExeWinSW = '{0}/{1}' -f $GolemDirectory, 'WinSW-x64.exe'
  $ConfigWinSW = '{0}/{1}' -f $GolemDirectory, 'WinSW-x64.xml'
  do {
    Show-Menu
    $input = Read-Host "  Please make a selection"
    Write-Host
    switch ($input) {
      '1' {
          Write-Host "Install/Update Yagna, Service, App-key, Test tokens"
          Write-Host
          Install-All $GolemDirectory $ExeWinSW $ConfigWinSW
        }
      '2' {
          Write-Host "Install service"
          Write-Host
          Check-Yagna-And-WinSW $GolemDirectory
          $WinSwStatus = Run-WinSW-Command $ExeWinSW $ConfigWinSW 'status'
          if (($WinSwStatus.Contains('Started')) -or ($WinSwStatus.Contains('Stopped'))) {
            Write-Host "    Service is already installed"        
          } else {
            Run-WinSW-Command $ExeWinSW $ConfigWinSW 'install'
            Write-Host "    Service installed with success"
          }
        }
      '3' {
          Write-Host "Uninstall service"
          Write-Host
          Check-Yagna-And-WinSW $GolemDirectory
          $WinSwStatus = Run-WinSW-Command $ExeWinSW $ConfigWinSW 'status'
          if ($WinSwStatus.Contains('Started')) {
            Write-Host "    Error, service is started, please stop it before"       
          } elseif ($WinSwStatus.Contains('Stopped')) {
            Run-WinSW-Command $ExeWinSW $ConfigWinSW 'uninstall'
            Write-Host "    Service uninstalled with success"
          } else {
            Write-Host "    Service is not installed"
          }
        }
      '4' {
          Write-Host "Start service"
          Write-Host
          Check-Yagna-And-WinSW $GolemDirectory
          $WinSwStatus = Run-WinSW-Command $ExeWinSW $ConfigWinSW 'status'
          if ($WinSwStatus.Contains('Started')) {
            Write-Host "    Service is already started"      
          } elseif ($WinSwStatus.Contains('Stopped')) {
            Run-WinSW-Command $ExeWinSW $ConfigWinSW 'start'
            Write-Host "    Service started with success"
          } else {
            Write-Host "    Error, service is not installed"
          }
        }
      '5' {
          Write-Host "Stop service"
          Write-Host
          Check-Yagna-And-WinSW $GolemDirectory
          $WinSwStatus = Run-WinSW-Command $ExeWinSW $ConfigWinSW 'status'
          if ($WinSwStatus.Contains('Started')) {
              Run-WinSW-Command $ExeWinSW $ConfigWinSW 'stop'
              Start-Sleep -Seconds 5
              Write-Host "    Service stopped with success"       
          } elseif ($WinSwStatus.Contains('Stopped')) {
              Write-Host "    Service is already stopped"
          } else {
              Write-Host "    Service is not installed"
          }
        }
      '6' {
          Write-Host "Restart service"
          Write-Host
          Check-Yagna-And-WinSW $GolemDirectory
          $WinSwStatus = Run-WinSW-Command $ExeWinSW $ConfigWinSW 'status'
          if ($WinSwStatus.Contains('Started')) {
            Run-WinSW-Command $ExeWinSW $ConfigWinSW 'restart'
            Write-Host "    Service restarted with success"     
          } elseif ($WinSwStatus.Contains('Stopped')) {
            Write-Host "    Error, service is not started"
          } else {
            Write-Host "    Error, service is not installed"
          }
        }
      '7' {
          Write-Host "Get service status"
          Write-Host
          Check-Yagna-And-WinSW $GolemDirectory
          Run-WinSW-Command $ExeWinSW $ConfigWinSW 'status'
        }
      '8' {
          Write-Host "Request test tokens"
          Write-Host
          Check-Yagna-And-WinSW $GolemDirectory
          $WinSwStatus = Run-WinSW-Command $ExeWinSW $ConfigWinSW 'status'
          if ($WinSwStatus.Contains('Started')) {
            Request-Test-Tokens $GolemDirectory     
          } elseif ($WinSwStatus.Contains('Stopped')) {
            Write-Host "    Error, service not started"
          } else {
            Write-Host "    Error, service is not installed"
          }
        }
      '0' {
          return
        }
    }
    Write-Host
    pause
  }
  until ($input -eq '0')
}

If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Start-Process -Verb RunAs -FilePath "powershell" -ArgumentList ('-ExecutionPolicy Bypass -File {0}' -f $MyInvocation.MyCommand.Path)
} else {
  cd (Split-Path -Path $MyInvocation.MyCommand.Path)
  Menu
}
