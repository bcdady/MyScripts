#!/usr/local/bin/powershell
#Requires -Version 3
# ~/.config/powershell/Microsoft.PowerShell_profile.ps1
#========================================
# NAME      : Microsoft.PowerShell_profile.ps1
# LANGUAGE  : Windows PowerShell
# AUTHOR    : Bryan Dady
# UPDATED   : 07/30/2017
# COMMENT   : Incorporate new module ConsoleTheme functions, with Set-Theme Function
#========================================
[CmdletBinding(SupportsShouldProcess)]
param ()
Set-StrictMode -Version latest

#Region MyScriptInfo
  Write-Verbose -Message '[$PROFILE] Populating $MyScriptInfo'
  $script:MyCommandName = $MyInvocation.MyCommand.Name
  $script:MyCommandPath = $MyInvocation.MyCommand.Path
  $script:MyCommandType = $MyInvocation.MyCommand.CommandType
  $script:MyCommandModule = $MyInvocation.MyCommand.Module
  $script:MyModuleName = $MyInvocation.MyCommand.ModuleName
  $script:MyCommandParameters = $MyInvocation.MyCommand.Parameters
  $script:MyParameterSets = $MyInvocation.MyCommand.ParameterSets
  $script:MyRemotingCapability = $MyInvocation.MyCommand.RemotingCapability
  $script:MyVisibility = $MyInvocation.MyCommand.Visibility

  if (($null -eq $script:MyCommandName) -or ($null -eq $script:MyCommandPath)) {
    # We didn't get a successful command / script name or path from $MyInvocation, so check with CallStack
    Write-Verbose -Message "Getting PSCallStack [`$CallStack = Get-PSCallStack]"
    $CallStack = Get-PSCallStack | Select-Object -First 1
    # $CallStack | Select Position, ScriptName, Command | format-list # FunctionName, ScriptLineNumber, Arguments, Location
    $script:myScriptName = $CallStack.ScriptName
    $script:myCommand = $CallStack.Command
    Write-Verbose -Message "`$ScriptName: $script:myScriptName"
    Write-Verbose -Message "`$Command: $script:myCommand"
    Write-Verbose -Message 'Assigning previously null MyCommand variables with CallStack values'
    $script:MyCommandPath = $script:myScriptName
    $script:MyCommandName = $script:myCommand
  }

  #'Optimize New-Object invocation, based on Don Jones' recommendation: https://technet.microsoft.com/en-us/magazine/hh750381.aspx
  $Private:properties = [ordered]@{
    'CommandName'        = $script:MyCommandName
    'CommandPath'        = $script:MyCommandPath
    'CommandType'        = $script:MyCommandType
    'CommandModule'      = $script:MyCommandModule
    'ModuleName'         = $script:MyModuleName
    'CommandParameters'  = $script:MyCommandParameters.Keys
    'ParameterSets'      = $script:MyParameterSets
    'RemotingCapability' = $script:MyRemotingCapability
    'Visibility'         = $script:MyVisibility
  }
  $MyScriptInfo = New-Object -TypeName PSObject -Prop $properties
  Write-Verbose -Message '[$PROFILE] $MyScriptInfo populated'
#End Region

Write-Output -InputObject " # Loading PowerShell `$Profile CurrentUserCurrentHost from $($MyScriptInfo.CommandPath) # "

# Detect older versions of PowerShell and add in new automatic variables for cross-platform consistency
if ($Host.Version.Major -le 5) {
  $Global:IsWindows = $true
  $Global:PSEdition = 'Native'
}

if ($IsWindows) {
  $hostOS = 'Windows'
  $hostOSCaption =  $((Get-CimInstance -ClassName Win32_OperatingSystem -Property Caption).Caption) -replace 'Microsoft ',''
}

if ((Get-Variable -Name IsLinux -ValueOnly -ErrorAction SilentlyContinue) -eq $true) {
  $hostOS = 'Linux'
  $hostOSCaption = $hostOS
} 

if ((Get-Variable -Name IsOSX -ValueOnly -ErrorAction SilentlyContinue) -eq $true) { 
  $hostOS = 'MacOS'
  $hostOSCaption = $hostOS
} 

# Write-Output -InputObject "`n ** To view additional available modules, run: Get-Module -ListAvailable"
# Write-Output -InputObject "`n ** To view Cmdlets available in a given module, run: Get-Command -Module <ModuleName>"
Write-Output -InputObject " # $ShellId $($Host.version.toString().substring(0,3)) $PSEdition on $hostOSCaption - $env:ComputerName #"

Write-Verbose -Message "Setting environment HostOS to $hostOS"
$env:HostOS = $hostOS

Get-Variable -Name Is* -Exclude ISERecent | Format-Table -AutoSize
<#
  Name                           Value
  ----                           -----
  IsCoreCLR                      True
  IsLinux                        False
  IsOSX                          True
  IsWindows                      False
#>

# Display execution policy, for convenience
Write-Output -InputObject "`nCurrent PS execution policy is: "
Get-ExecutionPolicy -List | Format-Table -AutoSize

$Global:onServer = $false
if ($hostOSCaption -like '*Windows Server*') {
  $Global:onServer = $true
}

<#
Make this more cross-platform / Core friendly
# Try to update PS help files, if we have local admin rights
# Check admin rights / role; same approach as Test-LocalAdmin function in Sperry module
if (([security.principal.windowsprincipal] [security.principal.windowsidentity]::GetCurrent()).isinrole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
  # Define constant, for where to look for PowerShell Help files, in the local network
  $HelpSource = '\\hcdata\apps\IT\PowerShell-Help'

  if (($onServer) -and (Test-Path -Path $HelpSource)) {
    Write-Log -Message "Preparing to update PowerShell Help from $HelpSource" -Verbose
    Update-Help -SourcePath $HelpSource -Recurse -Module Microsoft.PowerShell.*
    Write-Log -Message "PowerShell Core Help updated. To update help for all additional, available, modules, run Update-Help -SourcePath `$HelpSource -Recurse" -Verbose
  } else {
    Write-Log -Message "Failed to access PowerShell Help path: $HelpSource" -Verbose
  }
}
# else ... if not local admin, we don't have permissions to update help files.
#>

$global:LearnPowerShell = $false
if ($IsWindows -and (-not (Get-Variable -Name LearnPowerShell -Scope Global -ValueOnly -ErrorAction Ignore))) {
  # Learn PowerShell today ...
  # Thanks for this tip goes to: http://jdhitsolutions.com/blog/essential-powershell-resources/
  Write-Verbose -Message ' # selecting (2) random PowerShell cmdlet help to review #'
  
  Get-Command -Module Microsoft*, Cim*, PS*, ISE |
  Get-Random |
  Get-Help -ShowWindow

  Get-Random -Maximum (Get-Help -Name about_*) |
  Get-Help -ShowWindow
  [bool]$global:LearnPowerShell = $true
}

# Preset PSDefault Parameter Values 
# http://blogs.technet.com/b/heyscriptingguy/archive/2012/11/02/powertip-automatically-format-your-powershell-table.aspx
$PSDefaultParameterValues['Format-Table:AutoSize'] = $true
$PSDefaultParameterValues['Format-Table:wrap'] = $true
$PSDefaultParameterValues['Install-Module:Scope'] = 'CurrentUser'

<# Yes! This even works in XenApp!
  & Invoke-Expression (New-Object Net.WebClient).DownloadString('http://bit.ly/e0Mw9w')
  # start-sleep -Seconds 3
#>

# Derive full path to user's PowerShell folder
# if ($IsWindows) {
#   $myPSHome = $(Join-Path -Path "$([Environment]::GetFolderPath('MyDocuments'))" -ChildPath 'WindowsPowerShell')
#   if (($onServer) -or ($myPSHome -like '\\*')) {
#     # Detect UNC format in $myPSHome and replace with PDrive Name
#     foreach ($root in $(Get-PSDrive -PSProvider FileSystem | Where-Object -FilterScript { $null -ne $_.DisplayRoot })) {
#       Write-Debug -Message "$myPSHome -like $($root.DisplayRoot) : $($myPSHome -like $($root.DisplayRoot)+'*')"
#       if ($myPSHome  -like $($root.DisplayRoot)+'*') {
#         Write-Verbose -Message "Matched my PowerShell path to $($root.Name) ($($root.DisplayRoot))" -Verbose
#         $myPSHome = Resolve-Path -Path $($myPSHome -replace $(($root.DisplayRoot -replace '\\', '\\')  -replace '\$', '\$'), $($root.Root))
#       }
#     }
#   }
# } else {
  # Need to determine / test how to properly do this on non-windows OS
  $myPSHome = split-path -path $PROFILE #$HOME
#}

#Write-Verbose -Message "PowerShell profile root (`$myPSHome) is:  $myPSHome"
Write-Verbose -Message "`$myPSHome is $myPSHome"
Write-Output -InputObject "PS .\> $((Push-Location -Path $myPSHome -PassThru | Select-Object -Property Path).Path)"

<# check and conditionally update/fix PSModulePath
  on Mac, default PSMODULEPATH (yes, it's case sensitive) is: $env:USERPROFILE/.local/share/powershell/Modules;;/usr/local/microsoft/powershell/Modules
#>

Write-Verbose -Message 'Checking $env:PSModulePath for user modules path ($myPSModPath)'
if ($IsWindows) {
  $splitChar = ';'
  # Use local $HOME if GPO/UNC $HOME is not available
  if (-not (Test-Path -Path $HOME)) {
    Write-Verbose -Message 'Setting $HOME to $myPSHome'
    Set-Variable -Name HOME -Value $(Split-Path -Path $myPSHome -Parent) -Force
  }

    #Define modules and scripts folders within user's PowerShell folder
  $myPSModPath = (Join-Path -Path $myPSHome -ChildPath 'Modules')
  $myScriptsPath = (Join-Path -Path $myPSHome -ChildPath 'Scripts')

} else {
  $splitChar = ':'
  # if (-not (Test-Path -Path $HOME)) {
  #   Write-Verbose -Message 'Setting $HOME to $myPSHome'
  #   Set-Variable -Name HOME -Value $(Split-Path -Path $myPSHome -Parent) -Force
  # }

  $myPSModPath = (Join-Path -Path $HOME -ChildPath '.local/share/powershell/Modules') # OR /usr/local/share/powershell/Modules
  $myScriptsPath = (Join-Path -Path $HOME -ChildPath '.local/share/powershell/Scripts')
}

# Create the Path items, if necessary
if (-not (Test-Path -Path $myPSModPath)) {
  New-Item -Path $myPSHome -ItemType Directory -Name 'Modules'
  Write-Warning -Message 'FYI - The newly created Scripts directory is empty'
}

if (-not (Test-Path -Path $myScriptsPath)) {
  New-Item -Path $myPSHome -ItemType Directory -Name 'Scripts'
  Write-Warning -Message 'FYI - The newly created Scripts directory is empty'
}

# Locate MyScripts Repository, to copy from later, if needed
if (Join-Path -Path $HOME -ChildPath '*/MyScripts' -Resolve) {
  $MyScriptsRepo = Join-Path -Path $HOME -ChildPath '*/MyScripts' -Resolve
}

Write-Verbose -Message "My PS Modules Path: $myPSModPath"
Write-Verbose -Message "My PS Scripts Path: $myScriptsPath"

# From recent $PROFILE posted to github.com/PowerShell
if ($IsWindows)
{
	# Add Windows PowerShell PSModulePath to make it easier to discover potentially compatible PowerShell modules
	# If a Windows PowerShell module works or not, please provide feedback at https://github.com/PowerShell/PowerShell/issues/4062

	Write-Warning "Appended Windows PowerShell PSModulePath"
	$env:psmodulepath += ";${env:userprofile}\Documents\WindowsPowerShell\Modules;${env:programfiles}\WindowsPowerShell\Modules;${env:windir}\system32\WindowsPowerShell\v1.0\Modules\"
}

Write-Debug -Message "($myPSModPath -in @(`$env:PSMODULEPATH -split $splitChar)"
Write-Debug -Message ($myPSModPath -in @($env:PSMODULEPATH -split $splitChar))
if (($null -ne $myPSModPath) -and (-not ($myPSModPath -in @($env:PSMODULEPATH -split $splitChar)))) {
  # Improve to only conditionally modify 
  # $env:PSMODULEPATH = $myPSHome\Modules"; "$PSHome\Modules"; "${env:ProgramFiles(x86)}\WindowsPowerShell\Modules"; "$env:ProgramFiles\WindowsPowerShell\Modules") -join ';'
  Write-Verbose -Message "Adding Modules Path: $myPSModPath to `$env:PSMODULEPATH" -Verbose
  $env:PSMODULEPATH += "$splitChar$myPSModPath"

  # post-update cleanup
  $CleanModPathScript = Join-Path -Path $myScriptsPath -ChildPath 'Cleanup-ModulePath.ps1'
  if (Test-Path -Path $CleanModPathScript) {
    & $CleanModPathScript
    $env:PSMODULEPATH
  }
}

Write-Verbose -Message 'Declaring function Get-Function'
function Get-Function {
  Get-ChildItem -Path function: | Where-Object -FilterScript {$_.ModuleName -ne ''} | Sort-Object -Property ModuleName,Name
} # end Get-Function

function Invoke-WinSleep {
    & rundll32.exe powrprof.dll,SetSuspendState Sleep
}
New-Alias -Name GoTo-Sleep -Value Invoke-WinSleep -ErrorAction Ignore
New-Alias -Name Sleep-PC -Value Invoke-WinSleep -ErrorAction Ignore

# Client-only tweaks(s) ...
if ($Global:IsWindows -and (-not $onServer)) {
  # "Fix" task bar icon grouping
  # I sure wish there was an API for this so I didn't have to restart explorer
  Write-Verbose -Message 'Checking Task Bar buttons display preference'
  if ($((Get-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name TaskbarGlomLevel).TaskbarGlomLevel) -ne 0) {
    Write-Output -InputObject 'Setting registry preference to group task bar icons, and re-starting explorer to activate the new setting.'
    Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name TaskbarGlomLevel -Value 1 -Force
    Start-Sleep -Milliseconds 50
    Get-Process -Name explorer* | Stop-Process
  }
}

Write-Verbose -Message 'Checking that .\scripts\ folder is available'
if (($variable:myScriptsPath) -and (Test-Path -Path $myScriptsPath -PathType Container)) {
  Write-Verbose -Message 'Loading scripts from .\scripts\ ...'
  Write-Output -InputObject ''

    $atWork = $false
    # [bool]($NetInfo.IPAddress -match "^10\.\d{1,3}\.\d{1,3}\.\d{1,3}$") -or
    if ($Global:IsWindows -and (-not $onServer)) {
      if (Test-Connection -ComputerName $env:USERDNSDOMAIN -Quiet) {
        $atWork = $true
      }

      Write-Verbose -Message ' ... loading NetSiteName.ps1'
        # dot-source script file containing Get-NetSite function
      . (Join-Path -Path $myScriptsPath -ChildPath 'NetSiteName.ps1')

      Write-Verbose -Message '     Getting $NetInfo (IPAddress, SiteName)'
      # Get network / site info
      $NetInfo = Get-NetSite | Select-Object -Property IPAddress, SiteName -ErrorAction Stop
      if ($NetInfo) {
        if ($atWork) {
          Write-Output -InputObject "Connected at work site: $($NetInfo.SiteName) (Address: $($NetInfo.IPAddress))" # | Select-Object -First 1))"
        } else {
          Write-Output -InputObject "Connected at remote site: $($NetInfo.SiteName) (Address: $($NetInfo.IPAddress))" # | Select-Object -First 1))"
        }
      } else {
        Write-Warning -Message "Failed to enumerate Network Site Info: $NetInfo" # | Select-Object -First 1))"
      }
    }

  # dot-source script file containing Get-MyNewHelp function
  if (-not (Test-Path -Path $myScriptsPath\Get-MyNewHelp.ps1)) {
    Copy-Item -Path (Join-Path -Path $MyScriptsRepo -ChildPath 'Get-MyNewHelp.ps1') -Destination $myScriptsPath -PassThru
    # and make sure the new file is X
    & chmod +x (Join-Path -Path $myScriptsPath -ChildPath 'Open-PSEdit.ps1')
  }
  Write-Verbose -Message 'Initializing Get-MyNewHelp.ps1'
  . $myScriptsPath\Get-MyNewHelp.ps1 -Verbose
  
  # dot-source script file containing Merge-Repository and helper Merge-MyPSFiles functions
  if (-not (Test-Path -Path $myScriptsPath\PowerDiff.ps1)) {
    Copy-Item -Path (Join-Path -Path $MyScriptsRepo -ChildPath 'PowerDiff.ps1') -Destination $myScriptsPath -PassThru
    # and make sure the new file is X
    & chmod +x (Join-Path -Path $myScriptsPath -ChildPath 'Open-PSEdit.ps1')
  }
  Write-Verbose -Message 'Initializing PowerDiff.ps1'
  . (Join-Path -Path $myScriptsPath -ChildPath 'PowerDiff.ps1')

  # dot-source script file containing psEdit (Open-PSEdit) and supporting functions
  if (-not (Test-Path -Path $myScriptsPath\Open-PSEdit.ps1)) {
    Copy-Item -Path (Join-Path -Path $MyScriptsRepo -ChildPath 'Open-PSEdit.ps1') -Destination $myScriptsPath -PassThru
    # and make sure the new file is X
    & chmod +x (Join-Path -Path $myScriptsPath -ChildPath 'Open-PSEdit.ps1')
  }
  if (-not (Test-Path -Path $myScriptsPath\Edit-Path.ps1)) {
    Copy-Item -Path (Join-Path -Path $MyScriptsRepo -ChildPath 'Edit-Path.ps1') -Destination $myScriptsPath -PassThru
    # and make sure the new file is X
    & chmod +x (Join-Path -Path $myScriptsPath -ChildPath 'Edit-Path.ps1')
  }
  Write-Verbose -Message 'Initializing Open-PSEdit.ps1'
  . (Join-Path -Path $myScriptsPath -ChildPath 'Open-PSEdit.ps1')

  if ($hostOS -eq 'MacOS') {
    # import the ConsoleTheme module, ... 
    # dot-source and run Set-ConsoleTheme
    if (-not (Test-Path -Path (Join-Path -Path $myPSModPath -ChildPath 'ConsoleTheme'))) {
      Copy-Item -Path (Join-Path -Path (Split-Path -Path $MyScriptsRepo) -ChildPath 'ConsoleTheme') -Destination $myPSModPath -Container -Recurse -PassThru
    }

    if (-not (Test-Path -Path $myScriptsPath\Set-ConsoleTheme.ps1)) {
      Copy-Item -Path (Join-Path -Path $MyScriptsRepo -ChildPath 'Set-ConsoleTheme.ps1') -Destination $myScriptsPath -PassThru
    # and make sure the new file is X
    & chmod +x (Join-Path -Path $myScriptsPath -ChildPath 'Set-ConsoleTheme.ps1')
    }
    Write-Verbose -Message 'Initializing Set-ConsoleTheme.ps1'
    . (Join-Path -Path $myScriptsPath -ChildPath 'Set-ConsoleTheme.ps1')
    Write-Verbose -Message 'Set-ConsoleTheme'
    Set-ConsoleTheme
      
  }

  if ($atWork) {
    # dot-source script file containing Citrix XenApp functions
    if (-not (Test-Path -Path $myScriptsPath\Start-XenApp.ps1)) {
      Copy-Item -Path (Join-Path -Path $MyScriptsRepo -ChildPath 'Start-XenApp.ps1') -Destination $myScriptsPath -PassThru
    }
    Write-Verbose -Message 'Initializing Start-XenApp.ps1'
    . (Join-Path -Path $myScriptsPath -ChildPath 'Start-XenApp.ps1')

    # dot-source script file containing my XenApp functions
    if (-not (Test-Path -Path $myScriptsPath\GBCI-XenApp.ps1)) {
      Copy-Item -Path (Join-Path -Path $MyScriptsRepo -ChildPath 'GBCI-XenApp.ps1') -Destination $myScriptsPath -PassThru
    }
    Write-Verbose -Message 'Initializing GBCI-XenApp.ps1'
    . (Join-Path -Path $myScriptsPath -ChildPath 'GBCI-XenApp.ps1')
  }
} else {
  Write-Warning -Message "Failed to locate Scripts folder $myScriptsPath; run any scripts."
}

Write-Verbose -Message 'Declaring function Find-UpdatedDSCResource'
function Find-UpdatedDSCResource {
  $MyDSCModules = Get-InstalledModule | Where-Object -FilterScript {($PSItem.Tags -like 'DSC') -and ($PSItem.CompanyName -eq 'PowerShellTeam') -or ($PSItem.Author -like 'Microsoft') } | Select-Object -Property Name, Version

  Write-Output -InputObject 'Checking PowerShellGallery for new or updated DSC Resources (from Microsoft / PowerShellTeam)'
  Write-Verbose -Message 'Find-Package -ProviderName PowerShellGet -Tag DscResource' # | Format-List -Property Name,Status,Summary'
  #Find-Package -ProviderName PowerShellGet -Tag DscResource | Format-List -Property Name,Status,Summary | Out-Host -Paging
  $DSCResources = Find-Module -Tag DscResource -Repository PSGallery | Where-Object -FilterScript {($PSItem.CompanyName -eq 'PowerShellTeam') -or ($PSItem.Author -like 'Microsoft')}
  foreach ($pkg in $DSCResources) {
    Write-Debug -Message "$($pkg.Name) -in $($MyDSCModules.Name)"
    Write-Debug -Message $($pkg.Name -in $MyDSCModules.Name)
    if ($pkg.Name -in $MyDSCModules.Name) {
      # Retrieve matching local DSC resource module info
      $thisMod = $MyDSCModules | Where-Object -FilterScript { $PSItem.Name -eq $($pkg.Name) }
      Write-Debug -Message $thisMod
      Write-Debug -Message ($pkg.Version -gt $thisMod.Version)
      if ($pkg.Version -gt $thisMod.Version) {
        #Write-Verbose -Message 
        Write-Output -InputObject "Update to $($pkg.Name) is available"
        Write-Output -InputObject "Local: $($thisMod.Version) ; Repository: $($pkg.Version)"
        Update-Module -Name $($pkg.Name) -Confirm
      }
    } else {
      Write-Output -InputObject 'Reviewing new DSC Resource module packages available from PowerShellGallery'
      $pkg | Format-List -Property Name, Description, Dependencies, PublishedDate
      if ([string](Read-Host -Prompt 'Would you like to install this resource module? [Y/N]') -eq 'y') {
        Write-Verbose -Message "Installing and importing $($pkg.Name) from PowerShellGallery" -Verbose
        $pkg | Install-Module -Scope CurrentUser -Confirm
        Import-Module -Name $pkg.Name -PassThru
      } else {
        Write-Verbose -Message ' moving on ...'
      }
      Write-Verbose -Message ' # # # Next Module # # #'
    }
  }
} # end Find-UpdatedDSCResource

Write-Output -InputObject ' Try Find-UpdatedDSCResource'

Write-Verbose -Message 'Declaring function Find-NewGalleryModule'
function Find-NewGalleryModule {
  Find-Module -Repository PSGallery |
  Where-Object -FilterScript {$PSItem.Tags -NotLike 'DscResource'} |
  Sort-Object -Descending -Property PublishedDate |
  Select-Object -First 30 |
  Format-List -Property Name, PublishedDate, Description, Version |
  Out-Host -Paging
} # end Find-NewGalleryModule

Write-Output -InputObject ' Try Find-NewGalleryModule'

function Update-UAC {
  [cmdletbinding()]
  Param(
    [Parameter(Position = 0)]
    [int16]
    $UACPref = '5'
  )

  if ($IsWindows) {
    # Check current UAC level via registry
    # We want ConsentPromptBehaviorAdmin = 5
    # thanks to http://forum.sysinternals.com/display-uac-status_topic18490_page3.html
    if (((Get-ItemProperty -path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -name 'ConsentPromptBehaviorAdmin').ConsentPromptBehaviorAdmin) -ne $UACPref) {
      # prompt for UAC update
      Write-Verbose -Message 'Opening User Account Control Settings dialog'
      & UserAccountControlSettings.exe
    }
    
    Write-Verbose -Message "UAC level is $((Get-ItemProperty -path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -name 'ConsentPromptBehaviorAdmin').ConsentPromptBehaviorAdmin)"
  }
} # end Update-UAC

function Save-Credential {
  [cmdletbinding(SupportsShouldProcess)]
  Param(
    [Parameter(Position = 0)]
    [string]
    $Variable = 'my2acct',
    [Parameter(Position = 1)]
    [string]
    $USERNAME = $(if($IsWindows){$env:USERNAME}else{$env:USER})
  )

  if ([bool](Get-Variable -Name $Variable -ErrorAction SilentlyContinue | Out-Null))
  {
    Write-Warning -Message "Variable $Variable is already defined"
    if ((read-host -prompt "Would you like to update/replace the credential stored in $Variable`? [y]|n") -ne 'y')
    {
      Write-Warning -Message 'Ok. Aborting Update-Credential.'
      throw 'User aborted function.'
    }
  }
  if ($USERNAME -NotMatch '\d$') {
    $UName = $($USERNAME+'2')
  } else {
    $UName = $USERNAME
  }

  Write-Output -InputObject "`n # Prompting to capture elevated credentials. #`n ..."

  Set-Variable -Name $Variable -Value $(Get-Credential -UserName $UName -Message 'Store admin credentials for convenient use later.') -Scope Global -Description 'Stored admin credentials for convenient re-use.'
  if ($?) {
    Write-Output -InputObject "Elevated credentials stored in variable: $Variable."
  }
} # end Save-Credential

New-Alias -Name rdp -Value Start-RemoteDesktop -ErrorAction Ignore
New-Alias -Name rename -Value Rename-Item -ErrorAction SilentlyContinue

# Backup local PowerShell log files
Write-Verbose -Message 'Archive PowerShell logs'
Backup-Logs

# if connected to work network, initiate logging on to work, via Set-Workplace function
if ($atWork)
{
  if (((Get-Date -DisplayHint Time).Hour -ge 6) -and ((Get-Date -DisplayHint Time).Hour -le 19))
  {
    if ($onServer) {
      Write-Output -InputObject 'Restore-VSCodePrefs'
      Restore-VSCodePrefs -WhatIf
      start-sleep -s 1

      if (Test-Path -Path $HOME\VSCode\bin\code.cmd -PathType Leaf) {
        Assert-PSEdit -Path $HOME\VSCode\bin\code.cmd
      }
    }
    # Write-Output -InputObject 'Open-PSEdit'
    # Open-PSEdit
    Save-Credential
    Write-Output -InputObject ' # # # Set-Workplace -Zone Office # # # '
    Set-Workplace -Zone Office
  }
} else {
  if ($Global:IsWindows) {
    Dismount-Path
    Write-Output -InputObject 'Work network not detected. Run ''Set-Workplace -Zone Remote'' to switch modes.'
  }
}