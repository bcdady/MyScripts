#!pwsh
#Requires -ShellId Microsoft.PowerShell -PSEdition Core 
#========================================
# NAME      : Microsoft.PowerShell_profile-Windows.ps1
# LANGUAGE  : Microsoft PowerShell Core
# AUTHOR    : Bryan Dady
# UPDATED   : 06/26/2019
# COMMENT   : Personal PowerShell Profile script, specific to running on a Windows host in PowerShell Core
#========================================
[CmdletBinding()]
param ()
#Set-StrictMode -Version latest

# Uncomment the following 2 lines for testing profile scripts with Verbose output
#'$VerbosePreference = ''Continue'''
#$VerbosePreference = 'Continue'

Write-Verbose -Message 'Detect -Verbose $VerbosePreference'
switch ($VerbosePreference) {
  Stop             { $IsVerbose = $True }
  Inquire          { $IsVerbose = $True }
  Continue         { $IsVerbose = $True }
  SilentlyContinue { $IsVerbose = $False }
  Default          { if ('Verbose' -in $PSBoundParameters.Keys) {$IsVerbose = $True} else {$IsVerbose = $False} }
}
Write-Verbose -Message ('$VerbosePreference = ''{0}'' : $IsVerbose = ''{1}''' -f $VerbosePreference, $IsVerbose)

#Region MyScriptInfo
  Write-Verbose -Message ('[{0}] Populating $MyScriptInfo' -f $MyInvocation.MyCommand.Name)
  $MyCommandName        = $MyInvocation.MyCommand.Name
  $MyCommandPath        = $MyInvocation.MyCommand.Path
  $MyCommandType        = $MyInvocation.MyCommand.CommandType
  $MyCommandModule      = $MyInvocation.MyCommand.Module
  $MyModuleName         = $MyInvocation.MyCommand.ModuleName
  $MyCommandParameters  = $MyInvocation.MyCommand.Parameters
  $MyParameterSets      = $MyInvocation.MyCommand.ParameterSets
  $MyRemotingCapability = $MyInvocation.MyCommand.RemotingCapability
  $MyVisibility         = $MyInvocation.MyCommand.Visibility

  if (($null -eq $MyCommandName) -or ($null -eq $MyCommandPath)) {
    # We didn't get a successful command / script name or path from $MyInvocation, so check with CallStack
    Write-Verbose -Message 'Getting PSCallStack [$CallStack = Get-PSCallStack]'
    $CallStack      = Get-PSCallStack | Select-Object -First 1
    # $CallStack | Select Position, ScriptName, Command | format-list # FunctionName, ScriptLineNumber, Arguments, Location
    $myScriptName   = $CallStack.ScriptName
    $myCommand      = $CallStack.Command
    Write-Verbose -Message ('$ScriptName: {0}' -f $myScriptName)
    Write-Verbose -Message ('$Command: {0}' -f $myCommand)
    Write-Verbose -Message 'Assigning previously null MyCommand variables with CallStack values'
    $MyCommandPath  = $myScriptName
    $MyCommandName  = $myCommand
  }

  #'Optimize New-Object invocation, based on Don Jones' recommendation: https://technet.microsoft.com/en-us/magazine/hh750381.aspx
  $properties = [ordered]@{
    'CommandName'        = $MyCommandName
    'CommandPath'        = $MyCommandPath
    'CommandType'        = $MyCommandType
    'CommandModule'      = $MyCommandModule
    'ModuleName'         = $MyModuleName
    'CommandParameters'  = $MyCommandParameters.Keys
    'ParameterSets'      = $MyParameterSets
    'RemotingCapability' = $MyRemotingCapability
    'Visibility'         = $MyVisibility
  }
  $MyScriptInfo = New-Object -TypeName PSObject -Property $properties
  Write-Verbose -Message ('[{0}] $MyScriptInfo populated' -f $MyInvocation.MyCommand.Name)

  # Cleanup
  foreach ($var in $properties.Keys) {
    Remove-Variable -Name ('My{0}' -f $var) -Force
  }
  Remove-Variable -Name properties
  Remove-Variable -Name var
      
  if ($IsVerbose) {
    Write-Verbose -Message '$MyScriptInfo:'
    $Script:MyScriptInfo
  }
#End Region

Write-Output -InputObject ' # Loading PowerShell Windows Profile Script #'
Write-Verbose -Message (' ... from {0} # ' -f $MyScriptInfo.CommandPath)

# Set PowerShell Default Parameter preferences
# * Add -Scope Current User, -AllowClobber
$PSDefaultParameterValues = @{
  'Format-Table:Autosize' = $true
  'Format-Table:wrap'     = $true
  'Get-Help:Examples'     = $true
  'Get-Help:Online'       = $true
  'Enter-PSSession:Credential'          = $(Get-Variable -Name elevated -ErrorAction SilentlyContinue)
  'Enter-PSSession:EnableNetworkAccess' = $true
  'New-PSSession:Credential'            = $(Get-Variable -Name elevated -ErrorAction SilentlyContinue)
  'New-PSSession:EnableNetworkAccess'   = $true
}

Write-Verbose -Message ' # Setting GIT_EXEC_PATH #'
# GIT_EXEC_PATH determines where Git looks for its sub-programs (like git-commit, git-diff, and others).

$git_bin_path = 'R:\IT\Microsoft Tools\VSCode\GitPortable\bin\git.exe'

if (Test-Path -Path $git_bin_path  -PathType Leaf -IsValid) {
  $Env:GIT_EXEC_PATH = Split-Path -Path $git_bin_path
} else {
  if (Get-Command -Name git.exe) {
    $git_bin_path = (Get-Command -Name git.exe | Select-Object -Property Source).Source
  } else {
    Write-Warning -Message ('Test-Path -Path {0} Failed; GIT_EXEC_PATH not set.' -f $git_bin_path)
  }
}

#  Check the current setting by running `git --exec-path`.
if (Get-Command -Name git -CommandType Application -All -ErrorAction SilentlyContinue) {
  & git.exe --exec-path
}
Remove-Variable -Name git_bin_path

<# Yes! This even works in XenApp!
    & Invoke-Expression (New-Object Net.WebClient).DownloadString('http://bit.ly/e0Mw9w')
    # start-sleep -Seconds 3
#>

# Write-Debug -Message (' # # # $VerbosePreference: {0} # # #' -f $VerbosePreference)

Write-Verbose -Message 'Declaring function Show-DesktopDocuments'
function Show-DesktopDocuments {
  Write-Verbose -Message 'Opening all Desktop Documents'
  # Open all desktop PDF files
  Get-ChildItem -Path $Env:USERPROFILE\Desktop\*.pdf | ForEach-Object { & $_ ; Start-Sleep -Milliseconds 400}
  # Open all desktop Word doc files
  Get-ChildItem -Path $Env:USERPROFILE\Desktop\*.doc* | ForEach-Object { & $_ ; Start-Sleep -Milliseconds 800}
} # end function Show-DesktopDocuments

Write-Verbose -Message ' # Declaring function Invoke-WinSleep #'
function Invoke-WinSleep {
  # Write-Verbose -Message 'Invoke-WinSleep function is not for Server'
  if (-not $onServer) {
    Write-Warning -Message 'Sleeping Windows in 30 seconds'
    'Enter Ctrl+C to abort'
    Write-Verbose -Message 'rundll32.exe" powrprof.dll, SetSuspendState Sleep'
    Start-Sleep -Seconds 30
    & "$Env:windir\system32\rundll32.exe" powrprof.dll, SetSuspendState Sleep
  }
}
New-Alias -Name GoTo-Sleep -Value Invoke-WinSleep -ErrorAction Ignore
New-Alias -Name Sleep-PC -Value Invoke-WinSleep -ErrorAction Ignore

Write-Verbose -Message ' # Declaring function Invoke-WinShutdown #'
function Invoke-WinShutdown {
  if ($onServer) {
    Write-Verbose -Message 'Invoke-WinShutdown function is not for Server'
  } else {
    Write-Warning -Message 'Shutting down Windows in 30 seconds'
    'Run shutdown /a to abort'
    & "$Env:windir\system32\shutdown.exe" /d p:0:0 /s /t 30
  }
}
New-Alias -Name Shutdown -Value Invoke-WinShutdown -ErrorAction Ignore
New-Alias -Name Shutdown-PC -Value Invoke-WinShutdown -ErrorAction Ignore

Write-Verbose -Message ' # Declaring function Invoke-WinRestart #'
function Invoke-WinRestart {
  if ($onServer) {
    Write-Verbose -Message 'Invoke-WinShutdown function is not for Server'
  } else {
    Write-Warning -Message 'Restarting Windows in 30 seconds'
    'Run shutdown /a to abort'
    & "$Env:windir\system32\shutdown.exe" /d p:0:0 /r /t 30
  }
}
New-Alias -Name Restart -Value Invoke-WinRestart -ErrorAction Ignore

<# 
    Printer info
    printmanagement\Get-Printer
    -OR-
    HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows NT\CurrentVersion\PrinterPorts

#>
function Get-MyBrowser {
  # map known Browser ProgIDs to their Windows Control Panel\Programs\Default Programs AppName
  $ProgramByProgID = @{
    'ChromeHTML'  = 'Google Chrome'
    'FirefoxURL'  = 'Firefox'
    'MSEdgeSSHTM' = 'Microsoft Edge'
    'IE.HTTP'     = 'Internet Explorer'
    'IE.HTTPS'    = 'Internet Explorer'
    'Undefined'   = 'Undefined'
  }

  $ProgID = (Get-ItemProperty -Path 'HKCU:\SOFTWARE\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice' -Name 'ProgID').ProgID

  if ($null -eq $ProgID) { $ProgID = 'Undefined' }

  $ProgID -match "^(\w+)\W*"
  if ($Matches.ContainsKey(1)) {
    $ProgIDMatch = $Matches[1]
  } else {
    Write-Warning -Message ('Unrecognized https UserChoice in registry: {0}' -f $ProgID)
    $ProgIDMatch = $ProgID
  }

  $BrowserInfo = @{
    'UserChoice'  = $ProgIDMatch
    'Browser'     = $ProgramByProgID.$ProgIDMatch
  }

  return $BrowserInfo
}

Write-Verbose -Message ' # Declaring function Initialize-PowerCLIEnvironment #'
function Initialize-PowerCLIEnvironment {
  # If PowerCLI snapin / modules are not loaded, then start Initialize-PowerCLIEnvironment.ps1
  # Check if the package is installed, and get it's path
  $PowerCLI_Path = Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'VMware\*\vSphere PowerCLI'
  # $PowerCLI_Path = Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'VMware\Infrastructure\vSphere PowerCLI' -Resolve
  if (Test-Path -Path $PowerCLI_Path) {
    $PowerCLI_Path = Resolve-Path -Path $PowerCLI_Path
    if (Get-Command -Name Get-PowerCLIVersion -ErrorAction SilentlyContinue) {
      'PowerCli version:'
      Get-PowerCLIVersion
    } else {
      if (Join-Path -Path $PowerCLI_Path -ChildPath 'Scripts\Initialize-PowerCLIEnvironment.ps1' -Resolve) {
        write-output -InputObject ' # Initialize-PowerCLIEnvironment #'
        & "$PowerCLI_Path\Scripts\Initialize-PowerCLIEnvironment.ps1"
      } else {
        Write-Warning -Message 'Found PowerCLI path/folder, but failed to load Initialize-PowerCLIEnvironment.ps1'
      }
    }
  }
}
'To use PowerCLI commands (for VMware), call Initialize-PowerCLIEnvironment'
Start-Sleep -Milliseconds 777

<#
    # Client-only tweaks(s) ...
    if (-not $onServer) {
    # 'Fix' task bar icon grouping
    # I sure wish there was an API for this so I didn't have to restart explorer
    Write-Verbose -Message ' # Checking Task Bar buttons display preference #'
    if ($((Get-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name TaskbarGlomLevel).TaskbarGlomLevel) -ne 1) {
    Write-Output -InputObject 'Setting registry preference to group task bar icons, and re-starting explorer to activate the new setting.'
    Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name TaskbarGlomLevel -Value 1 -Force
    Start-Sleep -Milliseconds 50
    Get-Process -Name explorer* | Stop-Process
    }
    }
#>

Write-Debug -Message (' # # # $VerbosePreference: {0} # # #' -f $VerbosePreference)
Write-Verbose -Message ' # Checking that .\scripts\ folder is available #'
$atWork = $false

if (($variable:myPSScriptsPath) -and (Test-Path -Path $myPSScriptsPath -PathType Container)) {
  Write-Verbose -Message ' # Loading scripts from .\scripts\ ... #'
  Write-Output -InputObject ''

  # dot-source script file containing Merge-MyPSFiles and related functions
  #Write-Verbose -Message ' # Initializing Merge-MyPSFiles.ps1 #'
  #. $myPSScriptsPath\Merge-MyPSFiles.ps1
  Initialize-MyScript -Path $myPSScriptsPath\Merge-MyPSFiles.ps1

  # dot-source script file containing Get-MyNewHelp function
  #Write-Verbose -Message ' # Initializing Get-MyNewHelp.ps1 #'
  #. $myPSScriptsPath\Get-MyNewHelp.ps1
  Initialize-MyScript -Path $myPSScriptsPath\Get-MyNewHelp.ps1

  Write-Verbose -Message ' # Test network availability of work domain #'
  #$atWork = $False
  # Test-Connection cmdlet is not included in PS Core 6, so replaced with custom Test-Port function
  # Test-Port -Target $Env:USERDNSDOMAIN -Port 445 | Format-List -Property ConnectionStatus, PortNumber, TargetHostName, TargetHostStatus
  # $ConnectionStatus = Test-Port -Target $Env:USERDNSDOMAIN -Port 445 | Format-List -Property ConnectionStatus, PortNumber, TargetHostName, TargetHostStatus
  if ((Test-Path -Path Env:USERDNSDOMAIN) -and ((Test-Port -Target $Env:USERDNSDOMAIN -Port 445).ConnectionStatus -eq 'Success')) {
    $atWork = $True
  }

  # dot-source script file containing Get-NetSite function
  #Write-Verbose -Message ' # Initializing NetSiteName.ps1 #'
  #. $myPSScriptsPath\NetSiteName.ps1
  Initialize-MyScript -Path $myPSScriptsPath\NetSiteName.ps1

  if (Get-Command -Name Get-NetSite -ErrorAction SilentlyContinue) {
    Write-Verbose -Message ' #      Getting $NetInfo (IPAddress, SiteName) #'
    # Get network / site info
    $NetInfo = Get-NetSite | Select-Object -Property IPAddress, SiteName -ErrorAction Stop
    # If this previous function didn't error out, then we first assume that we're working at a 'Remote' site.
    if ($NetInfo) {
      $SiteType = 'Remote'
      # But if SiteName is NOT 'Undefined' (and is therefore defined in NetSiteName.ps1), then we're at a Work site.
      if ($NetInfo.SiteName -NotLike 'Private*') {
        $SiteType = 'Work'
      }
      Write-Output -InputObject ('Connected at {0} site: {1} (Address: {2})' -f $SiteType, ($NetInfo.SiteName)[-1], $NetInfo.IPAddress[-1])
    } else {
      Write-Warning -Message ('Failed to enumerate Network Site Info: {0}' -f $NetInfo)
    }
    Remove-Variable -Name SiteType -ErrorAction SilentlyContinue
    Remove-Variable -Name NetInfo -ErrorAction SilentlyContinue
  } else {
    Write-Warning -Message 'Failed to Get-Command Get-NetSite'
  }

  # dot-source script file containing Citrix XenApp functions
  #Write-Verbose -Message ' # Initializing Start-XenApp.ps1 #'
  #. $myPSScriptsPath\Start-XenApp.ps1
  Initialize-MyScript -Path $myPSScriptsPath\Start-XenApp.ps1

  if (Get-Command -Name Get-SystemCitrixInfo -ErrorAction SilentlyContinue) {
    Write-Verbose -Message ' # Get-SystemCitrixInfo #'
    $CitrixInfo = Get-SystemCitrixInfo
    if ($CitrixInfo.DisplayName -eq 'N/A') {
      Write-Verbose -Message 'Not Running in a Citrix session'
    } else {
      '# Running in a Citrix session #'
      # Confirms $Global:onServer and defines/updates $Global:OnXAHost, and/or fetched Receiver version
      $CitrixInfo | Format-List
    }
  } else {
    Write-Warning -Message 'Failed to Get-Command Get-NetSite'
  }
    <#
    # dot-source script file containing my XenApp functions
    Write-Verbose -Message ' # Initializing GBCI-XenApp.ps1 #'
    . $myPSScriptsPath\GBCI-XenApp.ps1
  #>
} else {
  Write-Warning -Message ('Failed to locate Scripts folder {0}; run any scripts.' -f $myPSScriptsPath)
}

Write-Verbose -Message ' # Declaring function Save-Credential #'
function Save-Credential {
  [cmdletbinding()]
  Param(
    [Parameter(Position = 0)]
    [string]
    $Variable = 'elevated'
    ,
    [Parameter(Position = 1)]
    [string]
    $USERNAME = $(if ($IsWindows) {$Env:USERNAME} else {$Env:USER})
  )

  $SaveCredential = $false
  $VarValueSet = [bool](Get-Variable -Name $Variable -ValueOnly -ErrorAction SilentlyContinue)
  Write-Debug -Message ('$VarValueSet = ''{0}''' -f $VarValueSet)
  if ($VarValueSet) {
    Write-Warning -Message ('Variable ''{0}'' is already defined' -f $Variable)
    if ((read-host -prompt ('Would you like to update/replace the credential stored in {0}`? [y]|n' -f $Variable)) -ne 'y') {
      Write-Warning -Message 'Ok. Aborting Save-Credential.'
    }
  } else {
    Write-Verbose -Message ('Credential will be saved to variable ''{0}''' -f $Variable)
    $SaveCredential = $true
  }

  Write-Debug -Message ('$SaveCredential = {0}' -f $SaveCredential)
  if ($SaveCredential) {
    if ($USERNAME -NotMatch '\d$') {
      $UName = $($USERNAME + '0')
    } else {
      $UName = $USERNAME
    }

    Write-Output -InputObject ''
    Write-Output -InputObject ' # Prompting to capture elevated credentials. #'
    Write-Output -InputObject ' ...'
    Set-Variable -Name $Variable -Value $(Get-Credential -UserName $UName -Message 'Store admin credentials for convenient use later.') -Scope Global -Description 'Stored admin credentials for convenient re-use.'
    if ($?) {
      Write-Output -InputObject ('Elevated credentials stored in variable: {0}.' -f $Variable)
    }
  }
} # end Save-Credential

New-Alias -Name rdp -Value Start-RemoteDesktop -ErrorAction Ignore
New-Alias -Name rename -Value Rename-Item -ErrorAction SilentlyContinue

Write-Verbose -Message ' # Declaring function Get-SpecialFolder #'
function Get-SpecialFolder {
  [cmdletbinding()]
  Param(
    [Parameter(Position = 0)]
    [Alias('Name')]
    [string]
    $SpecialFolder = [Enum]::GetNames([Environment+SpecialFolder])[2]
    ,
    [Parameter(Position = 1)]
    [switch]
    $ListAvailable
  )

#    [Enum]::GetNames([Environment+SpecialFolder]) | ForEach-Object -Process { Write-Output -InputObject ('Special Folder {0} is at path {1}' -f $PSItem, [Environment]::GetFolderPath($PSItem)) }
  if ($ListAvailable) {
    [Enum]::GetNames([Environment+SpecialFolder])
  } else {
    return [Environment]::GetFolderPath($SpecialFolder)
  }

} # End Get-SpecialFolder


if ($PSEdition -eq 'Desktop') {

  Write-Verbose -Message ' ... checking status of PSGallery ...'
  # Check PSRepository status
  $PSGallery = Get-PSRepository -Name PSGallery | Select-Object -Property Name,InstallationPolicy
  if ($PSGallery.InstallationPolicy -ne 'Trusted') {
    Write-Output -InputObject '# Trusting PSGallery Repository #'
    Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
  } else {
    Get-PSRepository
  }
  Remove-Variable -Name PSGallery

  # Look in PSGallery for available modules to upgrade builtins
  ' # Looking for newer available modules #'
  # *** RFE! *** : make this a function to easily refresh this list of updated modules available, e.g. from PSGallery
  # * and move to the root profile script instead of the OS specific file?
  Get-Module | Where-Object -FilterScript {$_.Name -notlike 'Microsoft.*' -and $_.Version -ne '0.0'} | ForEach-Object -Process {Write-Verbose -Message ('{0} ({1})' -f $_.Name, $_.Version); Find-Package -Type Module -Source PSGallery -Name $_.Name -MinimumVersion $_.Version -ErrorAction SilentlyContinue | Select-Object -Property Name, Version, Source }

  if ($IsAdmin) {
    # try to update PowerShell help files
    Get-MyNewHelp
  } else {
    # Without admin rights (in Windows PowerShell Desktop), we can't update help
    ''
    'Not Admin; unable to update PowerShell help files'
    ''
  }
}

# if connected to work network, initiate logging on to work, via Set-Workplace function
'# Start-CitrixSession #'
Write-Verbose -Message ('At work = ''{0}''' -f $atWork)
if ($atWork) {
  if ($Global:OnXAHost) {
    # Check default browser and conditionally open Control Panel to Default Programs view, to make setting Firefox as default browser - before launching into Start-CitrixSession
    Get-MyBrowser | Format-Table -AutoSize
    Set-MyBrowser -Browser 'Firefox'
    Start-Sleep -Seconds 5
    # From .\Scripts\Start-XenApp.ps1
    Start-CitrixSession
    # Write-Verbose -Message ' # Save-Credential #'
    #Save-Credential
  }

  # Start with Set-Workplace on a Client
  # # Set-Workplace in-turn invokes Start-CitrixSession via configuration in Sperry.json (in Sperry module)
  if (-not $Global:onServer) {
    # From .\Scripts\GBCI-XenApp.ps1
    Write-Output -InputObject ' # # Set-Workplace -Zone Office # #'
    Set-Workplace -Zone Office
  }

} else {
  if (Get-Command -Name Dismount-Path -ErrorAction SilentlyContinue) {
    Write-Verbose -Message 'Dismount-Path'
    Dismount-Path
  }
  Write-Output -InputObject ' # # # Work network not detected. Run ''Set-Workplace -Zone Remote'' to switch modes.'
}

# Now we can check if VSCode should be (re-)installed and asserted as PSEdit
$RunCodeSetup = $false
# Install VSCode (User edition) if it should be re-installed in a volatile OS context (such as Citrix)
if (Test-Path -Path HKCU:\SOFTWARE\Classes\VSCode.ps1) {
  Write-Verbose -Message 'VSCode is installed, per VSCode.ps1 FTA'
  $VSCodePath = Split-Path -Path (((Get-Item -Path HKCU:\SOFTWARE\Classes\VSCode.ps1\shell\open\command).GetValue($NULL) -split ' ')[0] -replace '"')
  Write-Verbose -Message ('$VSCodePath is {0}' -f $VSCodePath)
} else {
  # VSCode should be (re-)installed for the current user
  $RunCodeSetup = $true
  $VSCodePath = ('{0}Programs\VSCode' -f $HOME)
}

if ($RunCodeSetup) {
  Install-VSCode -InstallPath $VSCodePath
}
Remove-Variable -Name RunCodeSetup -ErrorAction SilentlyContinue

'# [PSEdit] #'
#requires -module Edit-Module
if (($null -eq $Env:PSEdit) -or ($Env:PSEdit -like "*powershell*")) {
  # Assert-PSEdit will throw an error if the -Path it's pointed at doesn't resolve, so we test it first
  if ((Get-Command -Name Assert-PSEdit -ErrorAction SilentlyContinue) -and (Test-Path -Path (Join-Path -Path $VSCodePath -ChildPath 'code.exe'))) {
    Write-Verbose -Message ('Assert-PSEdit -Path {0}' -f (Join-Path -Path $VSCodePath -ChildPath 'code.exe' -Resolve))
    Assert-PSEdit -Path (Join-Path -Path $VSCodePath -ChildPath 'code.exe')
  } else {
    Write-Verbose -Message 'Assert-PSEdit'
    Assert-PSEdit
  }
}
Remove-Variable -Name VSCodePath -ErrorAction SilentlyContinue

# Write-Output -InputObject '# Pre-log backup #'
# Write-Output -InputObject ('$VerbosePreference: {0} is {1}' -f $VerbosePreference, $IsVerbose)
# Backup local PowerShell log files
Write-Output -InputObject 'Archive PowerShell logs'
Backup-Logs
# Write-Output -InputObject ('$VerbosePreference: {0} is {1}' -f $VerbosePreference, $IsVerbose)

Write-Output -InputObject ' # End of PowerShell Windows Profile Script #'

<#
    # For intra-profile/bootstrap script flow Testing
    Write-Output -InputObject ''
    Start-Sleep -Seconds 3
#>
