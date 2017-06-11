#!/usr/local/bin/powershell
#Requires -Version 3
# PowerShell $Profile
# Originally created by New-Profile cmdlet in ProfilePal Module; modified for ps-core compatibility (use on Mac) by @bcdady 2016-09-27
# ~/.config/powershell/Microsoft.PowerShell_profile.ps1

[cmdletbinding(SupportsShouldProcess)]
param()

$script:MyCommandName = $MyInvocation.MyCommand.Name
$script:MyCommandPath = $MyInvocation.MyCommand.Path
$script:MyCommandType = $MyInvocation.MyCommand.CommandType
$script:MyCommandModule = $MyInvocation.MyCommand.Module
$script:MyModuleName = $MyInvocation.MyCommand.ModuleName
#$script:MyCommandParameters = $MyInvocation.MyCommand.Parameters
#$script:MyParameterSets = $MyInvocation.MyCommand.ParameterSets
$script:MyRemotingCapability = $MyInvocation.MyCommand.RemotingCapability
$script:MyVisibility = $MyInvocation.MyCommand.Visibility

if (($null -eq $script:MyCommandName) -or ($null -eq $script:MyCommandPath))
{
  # We didn't get a successful command / script name or path from $MyInvocation, so check with CallStack
  Write-Verbose -Message "Getting PSCallStack [`$CallStack = Get-PSCallStack]"
  $CallStack = Get-PSCallStack | Select-Object -First 1
  # $CallStack | Select Position, ScriptName, Command | format-list # FunctionName, ScriptLineNumber, Arguments, Location
  $script:myScriptName = $CallStack.ScriptName
  $script:myCommand = $CallStack.Command
  Write-Verbose -Message "`$ScriptName: $script:myScriptName"
  Write-Verbose -Message "`$Command: $script:myCommand"
  Write-Verbose -Message 'Assigning previously null MyCommand variables with CallStack values' -Verbose
  $script:MyCommandPath = $script:myScriptName
  $script:MyCommandName = $script:myCommand
}

Write-Verbose -Message "`$MyCommand properties"
Write-Verbose -Message "`$MyCommandName: $script:MyCommandName"
Write-Verbose -Message "`$MyCommandPath: $script:MyCommandPath"
Write-Verbose -Message "`$MyCommandType: $script:MyCommandType"
Write-Verbose -Message "`$MyCommandModule: $script:MyCommandModule"
Write-Verbose -Message "`$MyModuleName: $script:MyModuleName"
Write-Verbose -Message "`$MyCommandParameters: $script:MyCommandParameters"
Write-Verbose -Message "`$MyParameterSets: $script:MyParameterSets"
Write-Verbose -Message "`$MyRemotingCapability: $script:MyRemotingCapability"
Write-Verbose -Message "`$MyVisibility: $script:MyVisibility"

Write-Output -InputObject " # Loading PowerShell `$Profile: $script:MyCommandName # "

# Detect older versions of PowerShell and add in new automatic variables for more recent cross-platform compatibility
if ($Host.Version.Major -le 5) 
{
  $Global:IsWindows = $true
  $Global:PSEDition = 'Native'
}

if ($IsWindows) {
  $hostOS = 'Windows'
  $hostOSCaption =  $((Get-CimInstance -ClassName Win32_OperatingSystem -Property Caption).Caption) -replace 'Microsoft ',''
} 
if ($IsLinux)   {
  $hostOS = 'Linux'
  $hostOSCaption = $hostOS
} 
if ($IsOSX)     { 
  $hostOS = 'OSX'
  $hostOSCaption = $hostOS
} 

# write-output "`n ** To view additional available modules, run: Get-Module -ListAvailable"
# write-output "`n ** To view cmdlets available in a given module, run: Get-Command -Module <ModuleName>"
Write-Output -InputObject " # $ShellId $($Host.version.tostring().substring(0,3)) $PSEdition on $hostOSCaption - $env:COMPUTERNAME #"

Write-Verbose -Message "Setting environment HostOS to $hostOS"
$env:HostOS = $hostOS

<# Get-Variable -Name Is* -Exclude ISERecent | Format-Table -AutoSize
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
if ((Get-WmiObject -Class Win32_OperatingSystem -Property Caption).Caption -like '*Windows Server*')
{
  $Global:onServer = $true
}

$global:LearnPowerShell = $false
if ($IsWindows -and (-not (Get-Variable -Name LearnPowerShell -Scope Global -ValueOnly -ErrorAction Ignore)))
{
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
$PSDefaultParameterValues['Format-Table:autosize'] = $true
$PSDefaultParameterValues['Format-Table:wrap'] = $true

$PSDefaultParameterValues['Install-Module:Scope'] = 'CurrentUser'

# Write-Output -InputObject ''
# Invoke-Expression (New-Object Net.WebClient).DownloadString('http://bit.ly/e0Mw9w')
# start-sleep -Seconds 3

# Derive full path to user's PowerShell folder
if ($IsWindows)
{
  $myPShome = $(Join-Path -Path "$([Environment]::GetFolderPath('MyDocuments'))" -ChildPath 'WindowsPowerShell')
  if (($onServer) -or ($myPShome -like '\\*'))
  {
    # Detect UNC format in $myPShome and replace with PDrive Name
    foreach ($root in $(Get-PSDrive -PSProvider FileSystem | Where-Object -FilterScript { $null -ne $_.DisplayRoot }))
    {
      Write-Debug -Message "$myPShome -like $($root.DisplayRoot) : $($myPShome -like $($root.DisplayRoot)+'*')"
      if ($myPShome  -like $($root.DisplayRoot)+'*')
      {
        Write-Verbose -Message "Matched my PowerShell path to $($root.Name) ($($root.DisplayRoot))" -Verbose
        $myPShome = Resolve-Path -Path $($myPShome -replace $(($root.DisplayRoot -replace '\\', '\\')  -replace '\$', '\$'), $($root.Root))
      }
    }
  }
}
else
{
  # Need to determine / test how to propertly do this on non-windows OS
  $myPShome = $HOME
}

#Write-Verbose -Message "PowerShell profile root (`$myPShome) is:  $myPShome"
$myPShome
Set-Location -Path $myPShome

<# check and conditionally update/fix PSModulePath
    on Mac, default PSMODULEPATH (yes, it's case sensitive) is: $env:USERPROFILE/.local/share/powershell/Modules;;/usr/local/microsoft/powershell/Modules
#>

Write-Verbose -Message 'Checking $env:PSModulePath for user modules path ($myPSmodPath)'
if ($IsWindows)
{
  $splitChar = ';'
  # Use local $HOME if GPO/UNC $HOME is not available
  if (-not (Test-Path -Path $HOME)) 
  {
    Write-Log -Message 'Setting $HOME to $myPShome' -Verbose
    Set-Variable -Name HOME -Value $(Split-Path -Path $myPShome -Parent) -Force
  }

  #Define modules and scripts folders within user's PowerShell folder, creating the subfolders if necesarry
  $myPSmodPath = (Join-Path -Path $myPShome -ChildPath 'Modules')
  if (-not (Test-Path -Path $myPSmodPath))
  {
    New-Item -Path $myPShome -ItemType Directory -Name 'Modules'
  }

  $myScriptsPath = (Join-Path -Path $myPShome -ChildPath 'Scripts')
  if (-not (Test-Path -Path $myScriptsPath))
  {
    New-Item -Path $myPShome -ItemType Directory -Name 'Scripts'
  }
}
else
{
  $splitChar = ':'
  if (-not (Test-Path -Path $HOME)) 
  {
    Write-Log -Message 'Setting $HOME to $myPShome' -Verbose
    Set-Variable -Name HOME -Value $(Split-Path -Path $myPShome -Parent) -Force
  }

  $myPSmodPath = (Join-Path -Path $HOME -ChildPath '.local/share/powershell/Modules') # OR /usr/local/share/powershell/Modules
  $myScriptsPath = (Join-Path -Path $HOME -ChildPath '.local/share/powershell/Scripts')
}

Write-Log -Message "My PS Modules Path: $myPSmodPath" -Verbose
Write-Log -Message "My PS Scripts Path: $myScriptsPath" -Verbose

Write-Debug -Message "($myPSmodPath -in @(`$env:PSMODULEPATH -split $splitChar)"
Write-Debug -Message ($myPSmodPath -in @($env:PSMODULEPATH -split $splitChar))
if (($null -ne $myPSmodPath) -and (-not ($myPSmodPath -in @($env:PSMODULEPATH -split $splitChar))))
{
  # Improve to only conditionally modify 
  # $env:PSMODULEPATH = $myPShome\Modules"; "$pshome\Modules"; "${env:ProgramFiles(x86)}\WindowsPowerShell\Modules"; "$env:ProgramFiles\WindowsPowerShell\Modules") -join ';'
  Write-Verbose -Message "Adding Modules Path: $myPSmodPath to `$env:PSMODULEPATH" -Verbose
  $env:PSMODULEPATH += "$splitChar$myPSmodPath"

  # post-update cleanup
  if (Test-Path -Path $myScriptsPath)
  {
    & $myScriptsPath\Cleanup-ModulePath.ps1
    $env:PSMODULEPATH
  }
}

# Move this to a function in it's own script file
# try to update PS help files, if we have local admin role/rights
Write-Verbose -Message 'Declaring function Get-Function'
function Get-Function {
  Get-ChildItem -Path function: | Where-Object -FilterScript {$_.ModuleName -ne ''} | Sort-Object -Property ModuleName,Name
}

<#
    # Load Sperry / Autopilot functions module
    Write-Output -InputObject ' # loading Sperry Module #'
    Import-Module -Name Sperry

    # Load ProfilePal module
    Write-Output -InputObject ' # loading ProfilePal Module #'
    Import-Module -Name ProfilePal
#>

# "Fix" task bar icon grouping
# I sure wish there was an API for this so I didn’t have to restart explorer
if ($((Get-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name TaskbarGlomLevel).TaskbarGlomLevel) -ne 0)
{
  Write-Output -InputObject 'Setting registry preference to group task bar icons, and re-starting explorer to activate the new setting.'
  Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name TaskbarGlomLevel -Value 0 -Force
  Start-Sleep -Milliseconds 50
  Get-Process -Name explorer* | Stop-Process
}

if (($variable:myScriptsPath) -and (Test-Path -Path $myScriptsPath -PathType Container))
{
  Write-Output -InputObject ''
  # dot-source script file containing Get-NetSite function
  . $myScriptsPath\NetSiteName.ps1

  # Get network / site info
  $NetInfo = Get-NetSite | Select-Object -Property IPAddress, SiteName
  Write-Output -InputObject "Connected at Site: $($NetInfo.SiteName) (Address: $($NetInfo.IPAddress))" # | Select-Object -First 1))"

  $atWork = $false
  if ([bool]($NetInfo.IPAddress -match "^10\.\d{1,3}\.\d{1,3}\.\d{1,3}$"))
  {
    $atWork = $true
  }

  Write-Output -InputObject ''
  # dot-source script file containing Get-NetSite function
  . $myScriptsPath\Get-MyNewHelp.ps1 -Verbose
  
  Write-Output -InputObject ''
  # dot-source script file containing PowerDiff function
  . $myScriptsPath\PowerDiff.ps1

  Write-Output -InputObject ''
  # dot-source script file containing psEdit (Open-Code) function
  . $myScriptsPath\VS-Code.ps1

  Write-Verbose -Message 'Importing function Out-Copy'
  # dot-source Out-Copy function script
  . $myScriptsPath\out-copy.ps1

  Write-Verbose -Message 'Importing function Out-Highlight'
  # dot-source Out-Highlight function script
  . $myScriptsPath\Out-Highlight.ps1
  
  Write-Verbose -Message 'Calling GBCI-XenApp.ps1'
  . $myScriptsPath\GBCI-XenApp.ps1
  
}
else
{
  Write-Warning -Message "Failed to locate Scripts folder $myScriptsPath; run any scripts."
}

<#Write-Verbose -Message ''
    Write-Verbose -Message 'Updating this window title'
    Set-WindowTitle
#>
Write-Verbose -Message 'Declaring function Find-UpdatedDSCResource'
function Find-UpdatedDSCResource 
{
  $MyDSCmodules = Get-InstalledModule | Where-Object -FilterScript {($PSItem.Tags -like 'DSC') -and ($PSItem.CompanyName -eq 'PowerShellTeam') -or ($PSItem.Author -like 'Microsoft') } | Select-Object -Property Name, Version

  Write-Output -InputObject 'Checking PowerShellGallery for new or updated DSC Resources (from Microsoft / PowerShellTeam)'
  Write-Verbose -Message 'Find-Package -ProviderName PowerShellGet -Tag DscResource' # | Format-List -Property Name,Status,Summary'
  #Find-Package -ProviderName PowerShellGet -Tag DscResource | Format-List -Property Name,Status,Summary | Out-Host -Paging
  $DSCResources = Find-Module -Tag DscResource -Repository PSGallery | Where-Object -FilterScript {($PSItem.CompanyName -eq 'PowerShellTeam') -or ($PSItem.Author -like 'Microsoft')}
  foreach ($pkg in $DSCResources)
  {
    Write-Debug -Message "$($pkg.Name) -in $($MyDSCmodules.Name)"
    Write-Debug -Message $($pkg.Name -in $MyDSCmodules.Name)
    if ($pkg.Name -in $MyDSCmodules.Name) 
    {
      # Retrieve matching local DSC resource module info
      $thisMod = $MyDSCmodules | where -FilterScript {$PSItem.Name -eq $($pkg.Name)}
      Write-Debug -Message $thisMod
      Write-Debug -Message ($pkg.Version -gt $thisMod.Version)
      if ($pkg.Version -gt $thisMod.Version) 
      {
        #Write-Verbose -Message 
        write-output -InputObject "Update to $($pkg.Name) is available"
        write-output -InputObject "Local: $($thisMod.Version) ; Repository: $($pkg.Version)"
        Update-Module -Name $($pkg.Name) -Confirm
      }
    }
    else
    {
      'Reviewing new DSC Resource module packages available from PowerShellGallery'
      $pkg | Format-List -Property Name, Description, Dependencies, PublishedDate
      if ([string](Read-Host -Prompt 'Would you like to install this resource module? [Y/N]') -eq 'y')
      {
        Write-Verbose -Message "Installing and importing $($pkg.Name) from PowerShellGallery" -Verbose
        $pkg | Install-Module -Scope CurrentUser -Confirm
        Import-Module -Name $pkg.Name -PassThru
      }
      else
      {
        Write-Verbose -Message ' moving on ...'
      }
      Write-Verbose -Message ' # # # Next Module # # #'
    }
  }
}

' Try Find-UpdatedDSCResource'

Write-Verbose -Message 'Declaring function Get-PSGalleryModule'
function Find-NewGalleryModule
{
  Find-Module -Repository psgallery |
  Where-Object -FilterScript {$PSItem.Tags -notlike 'DscResource'} |
  Sort-Object -Descending -Property PublishedDate |
  Select-Object -First 30 |
  Format-List -Property Name, PublishedDate, Description, Version |
  Out-Host -Paging
}

' Try Find-NewGalleryModule'

function Update-UAC
{
  [cmdletbinding(SupportsShouldProcess)]
  Param(
    [Parameter(Position = 0)]
    [int16]
    $UACpref = '5'
  )

  if ($IsWindows)
  {
    # Check current UAC level via registry
    # We want ConsentPromptBehaviorAdmin = 5
    # thanks to http://forum.sysinternals.com/display-uac-status_topic18490_page3.html
    if (((get-itemproperty -path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -name 'ConsentPromptBehaviorAdmin').ConsentPromptBehaviorAdmin) -ne $UACpref)
    {
      # prompt for UAC update
      Write-Verbose -Message 'Opening User Account Control Settings dialog'
      & UserAccountControlSettings.exe
    }
    
    Write-Verbose -Message "UAC level is $((get-itemproperty -path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' -name 'ConsentPromptBehaviorAdmin').ConsentPromptBehaviorAdmin)"
    
  }
}

function Save-Credential
{
  [cmdletbinding(SupportsShouldProcess)]
  Param(
    [Parameter(Position = 0)]
    [string]
    $Variable = 'my2acct'
    ,
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
  if ($USERNAME -notmatch '\d$')
  {
    $uname = $($USERNAME+'2')
  }
  else
  {
    $uname = $USERNAME
  }

  Write-Output -InputObject "`n # Prompting to capture elevated credentials. #`n ..."

  Set-Variable -Name $Variable -Value $(Get-Credential -UserName $uname -Message 'Store admin credentials for convenient use later.') -Scope Global -Description 'Stored admin credentials for convenient re-use.'
  if ($?)
  {
    Write-Output -InputObject "Elevated credentials stored in variable: $Variable."
  }
}

New-Alias -Name rdp -Value Start-RemoteDesktop -ErrorAction Ignore
New-Alias -Name rename -Value Rename-Item -ErrorAction SilentlyContinue

# Backup local PowerShell log files
Write-Verbose -Message 'Archive PowerShell logs'
Backup-Logs

# if connected to work network, initiate logging on to work, via Set-Workplace function
if (($atWork) -and ((Get-Date -DisplayHint Time).Hour -ge 6) -and ((Get-Date -DisplayHint Time).Hour -le 19))
{
  # Save-Credential
  Set-Workplace -Zone Office
}
else
{
  Write-Output -InputObject 'Work network not detected. Run ''Set-Workplace -Zone Remote'' to switch modes.'
}