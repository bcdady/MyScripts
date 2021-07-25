#!/usr/bin/env pwsh
#Requires -ShellId Microsoft.PowerShell -PSEdition Core 
#========================================
# NAME      : Microsoft.PowerShell_profile.ps1
# LANGUAGE  : Microsoft PowerShell
# Created by New-Profile function of ProfilePal module
# For more information, see https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles
#========================================
[CmdletBinding()]
param ()
#Set-StrictMode -Version latest

# Uncomment the following 2 lines for testing profile scripts with Verbose output
#'$VerbosePreference = ''Continue'''
#$VerbosePreference = 'Continue'

# Region MyScriptInfo
# Only call (and use results from Get-MyScriptInfo function, if it was loaded from ./Bootstrap.ps1)
if (Test-Path -Path Function:\Get-MyScriptInfo) {
    $MyScriptInfo = Get-MyScriptInfo($MyInvocation) -Verbose

    if ($IsVerbose) { $MyScriptInfo }    
}
#End Region

# capture starting path so we can go back after other things below might move around
$startingPath = $PWD.Path

Write-Output -InputObject ' # Loading PowerShell $Profile: CurrentUserCurrentHost'
Write-Verbose -Message (' ... from {0} # ' -f $MyScriptInfo.CommandPath)
# Display PowerShell Execution Policy -- on Windows only (as ExecutionPolicy is not supported on non-Windows platforms)
if ($IsWindows) {
    Write-Output -InputObject 'Current PS execution policy is:'
    Get-ExecutionPolicy -List
}

Push-Location -Path $MyScriptInfo.CommandRoot -PassThru

# https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_prompts
if ($IsVerbose) {Write-Output -InputObject ''}
Write-Verbose -Message 'Defining custom prompt'
function prompt {
    if (-not (Test-Path -Path Variable:\IsAdmin)) {
        # $IsWindows, if not already provided by pwsh $Host, is set in bootstrap.ps1
        if ($IsWindows) {
            $IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')
        } else {
            $IsAdmin = $False
        }
    }
    if ($IsAdmin) { $AdminPrompt = '[ADMIN]:' } else { $AdminPrompt = '' }
    if (Get-Variable -Name PSDebugContext -ValueOnly -ErrorAction SilentlyContinue) { $DebugPrompt = '[DEBUG]:' } else { $DebugPrompt = '' }
    if (Get-Variable -Name PSConsoleFile -ValueOnly -ErrorAction SilentlyContinue)  { $PSCPrompt = "[PSConsoleFile: $PSConsoleFile]" } else { $PSCPrompt = '' }
    if ($NestedPromptLevel -ge 1) { $PromptLevel = 'PS .\> >' } else { $PromptLevel = 'PS .\>' }

    return "[{0} @ {1}]`n{2}{3}{4}{5}" -f $Env:COMPUTERNAME, $PWD.Path, $AdminPrompt, $PSCPrompt, $DebugPrompt, $PromptLevel
}
if ($IsVerbose) {Write-Output -InputObject ''}

#Region Bootstrap
# Invoke Bootstrap.ps1, from the same root path as this $PROFILE script
if (Get-Variable -Name 'myPS*' -ValueOnly -ErrorAction SilentlyContinue) {
    # PowerShell path variables have been initialized via a recent invocation of bootstrap.ps1
    Write-Output -InputObject ''
    Write-Output -InputObject 'My PowerShell paths:'
    Get-Variable -Name 'myPS*' | Format-Table -AutoSize
} else {
    # initialize variables, via bootstrap.ps1
    Write-Verbose -Message ('(Test-Path -Path ./bootstrap.ps1): {0}' -f (Test-Path -Path ./Bootstrap.ps1))
    if (Test-Path -Path ./Bootstrap.ps1) {
        #Write-Verbose -Message '. ./Bootstrap.ps1'
        . ./Bootstrap.ps1
    }
    if (Get-Variable -Name 'myPS*' -ValueOnly -ErrorAction SilentlyContinue) {
        # PowerShell path variables have been initialized via a recent invocation of bootstrap.ps1
        Write-Output -InputObject ''
        Write-Output -InputObject 'My PowerShell paths:'
        Get-Variable -Name 'myPS*' | Format-Table -AutoSize
    } else {
        Write-Warning -Message './Bootstrap.ps1 may have encountered errors.'
    }
#End Region

<# Yes! This even works in XenApp!
    & Invoke-Expression (New-Object Net.WebClient).DownloadString('http://bit.ly/e0Mw9w')
    # start-sleep -Seconds 3
#>
if (Get-Command -Name Set-ConsoleTitle -ErrorAction SilentlyContinue) {
    # Call Set-ConsoleTitle, from ProfilePal module
    if ($IsVerbose) {Write-Output -InputObject ''}
    Write-Verbose -Message ' # Set-ConsoleTitle >'
    Set-ConsoleTitle
    Write-Verbose -Message ' # < Set-ConsoleTitle'
    if ($IsVerbose) {Write-Output -InputObject ''}
}

# In case any intermediary scripts or module loads change our current directory, restore original path, before it's locked into the window title by Set-ConsoleTitle
Set-Location $startingPath

# Loading ProfilePal Module, and only if successful, call Set-ConsoleTitle to customize the ConsoleHost window title
Import-Module -Name ProfilePal
if ($?) {
    # Call Set-ConsoleTitle function from ProfilePal module
    Set-ConsoleTitle
}

function Initialize-MyScript {
    [cmdletbinding()]
    param(
      # Specifies a path to a script to be run
      [Parameter(Mandatory,
        Position=0,
        ParameterSetName="ParameterSetName",
        ValueFromPipeline,
        ValueFromPipelineByPropertyName,
        HelpMessage="Path to one or more locations.")]
      [Alias("PSPath")]
      [ValidateNotNullOrEmpty()]
      [ValidateScript({ (Test-Path -Path $PSItem -PathType Leaf),ErrorMessage = "    Error: Test-Path failed. $PSItem not found.") }
        ]
      [string[]]
      $Path
    )
    
    # Begin block of Advanced Function
    Begin {
      Test-Path -Path $Path -PathType Leaf -ErrorAction Stop
      $ScriptName = Split-Path -Path $Path -Leaf
    } # End of Begin block
    
    # Process block of Advanced Function
    Process {
      Write-Verbose -Message (' # Initializing {0} #' -f $ScriptName)
      Write-Verbose -Message (' # From Path: {0} #' -f $Path)
      # dot-source script file containing Merge-MyPSFiles and related functions
      . $Path
      
    } # End of Process block
    
    # End block of Advanced Function
    End {
    
    } # End of End block 
    
  }

Write-Verbose -Message ('$HostOS = ''{0}''' -f $HostOS)
# Detect host OS and then jump to the OS specific profile sub-script
if ($IsLinux) {
    $Private:SubProfile = (Join-Path -Path (split-path -Path $MyScriptInfo.CommandPath) -ChildPath 'Microsoft.PowerShell_profile-Linux.ps1')
}

if ($IsMacOS) {
    $Private:SubProfile = (Join-Path -Path (split-path -Path $MyScriptInfo.CommandPath) -ChildPath 'Microsoft.PowerShell_profile-macOS.ps1')
}

if ($IsWindows) {
    $Private:SubProfile = (Join-Path -Path (split-path -Path $MyScriptInfo.CommandPath) -ChildPath 'Microsoft.PowerShell_profile-Windows.ps1')
}

if ($IsVerbose) {Write-Output -InputObject ''}
Write-Verbose -Message ('$SubProfile = ''{0}''' -f $Private:SubProfile)

# Load/invoke OS specific profile sub-script
if (Test-Path -Path $SubProfile) {
    # dot-source it
    . $SubProfile
} else {
    throw ('Failed to locate OS specific profile sub-script: {0}' -f $SubProfile)
}
Remove-Variable -Name SubProfile -Force

# Here's an example of how convenient aliases can be added to your PS profile
New-Alias -Name rdp -Value Start-RemoteDesktop -ErrorAction Ignore

Write-Output -InputObject ''
Write-Output -InputObject ' ** To view additional available modules, run: Get-Module -ListAvailable'
Write-Output -InputObject ' ** To view cmdlets available in a given module, run: Get-Command -Module <ModuleName>'

# Do you like easter eggs?:
#& iex (New-Object Net.WebClient).DownloadString('http://bit.ly/e0Mw9w')

if ($IsVerbose) {Write-Output -InputObject ''}
Write-Output -InputObject ' # End of PowerShell $Profile CurrentUserCurrentHost #'

# For intra-profile/bootstrap script flow Testing
if ($IsVerbose) {
    Write-Output -InputObject 'Start-Sleep -Seconds 3'
    Start-Sleep -Seconds 3
}
