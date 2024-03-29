#!/usr/bin/env pwsh
#Requires -Version 3
#========================================
# NAME      : Microsoft.PowerShell_profile.ps1
# LANGUAGE  : Microsoft PowerShell
# Created by New-Profile function of ProfilePal module
# For more information, see https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles
#========================================
[CmdletBinding()]
param ()

# Uncomment the following 2 lines for testing profile scripts with Verbose output
#'$VerbosePreference = ''Continue'''
#$VerbosePreference = 'Continue'

Write-Verbose -Message 'Importing function Initialize-MyScript'
function global:Initialize-MyScript {
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
      [ValidateScript({
            If (Test-Path -Path $PSItem -PathType Leaf) {
                $True
            } else {
                Throw "$PSItem not found"
            }
        })]
      [System.Object[]]
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
      return $?
      
    } # End of Process block
    
    # End block of Advanced Function
    End { }

}

# Region Bootstrap
# Invoke Bootstrap.ps1, from the same root path as this $PROFILE script
if (Get-Variable -Name 'myPS*' -ValueOnly) { # -ErrorAction SilentlyContinue) {
    # PowerShell path variables have been initialized via a recent invocation of bootstrap.ps1
    Write-Output -InputObject ''
    Write-Output -InputObject 'My PowerShell paths:'
    Get-Variable -Name 'myPS*' | Format-Table -AutoSize
    Write-Verbose -Message 'Detected myPS* variable exist, so we infer that Bootstrap has been run'
} else {
    # initialize variables, via bootstrap.ps1
    # Make sure we're in the current directory as this script
    $Bootstrap = Join-Path -Path (Split-Path -Path $MyInvocation.MyCommand.Path) -ChildPath 'Bootstrap.ps1'
    Write-Verbose -Message ('(Test-Path -Path {0}): {1}' -f $Bootstrap, (Test-Path -Path $Bootstrap))
    if ($IsVerbose) { start-sleep -seconds 3 }
    if (Test-Path -Path $Bootstrap) {
        # Dot-source Bootstrap script
        Write-Verbose -Message 'Initialize-MyScript -Path  ./Bootstrap.ps1'
        Initialize-MyScript -Path $Bootstrap
    } else {
        ThrowError ('Did not find ./Bootstrap.ps1 in {0}' -f $PWD)
    }
    # else, we proceed gracefully
    if (Get-Variable -Name 'myPS*' -ValueOnly -ErrorAction SilentlyContinue) {
        # PowerShell path variables have been initialized via a recent invocation of bootstrap.ps1
        Write-Output -InputObject ''
        Write-Output -InputObject 'My PowerShell paths:'
        Get-Variable -Name 'myPS*' | Format-Table -AutoSize
    } else {
        Write-Warning -Message ' ! Supporting script ./Bootstrap.ps1 may have encountered errors.'
    }
}
#End Region

# Region MyScriptInfo
# Only call (and use results from Get-MyScriptInfo function, if it was loaded from ./Bootstrap.ps1)
if (Test-Path -Path Function:\Get-MyScriptInfo) {
    $MyScriptInfo = Get-MyScriptInfo($MyInvocation) -Verbose
    if ($IsVerbose) { $MyScriptInfo }
} else {
    Write-Warning -Message ' ! Failed to locate Function:\Get-MyScriptInfo (which is supposed to be instantiated by ./Bootstrap.ps1'
    Write-Verbose -Message ' Subsequent functions or cmdlets may not work as expected.'
}
#End Region

# capture starting path so we can go back after other things below might move around
$startingPath = $PWD.Path

Write-Output -InputObject ' # Loading PowerShell $Profile: CurrentUserCurrentHost #'
Write-Verbose -Message (' ... from {0} # ' -f $MyScriptInfo.CommandPath)

# Display PowerShell Execution Policy -- on Windows only (as ExecutionPolicy is not supported on non-Windows platforms)
if ($IsWindows) {
    Write-Output -InputObject 'Current PS execution policy is:'
    Get-ExecutionPolicy -List
}

Push-Location -Path $MyScriptInfo.CommandRoot -PassThru

# In case any intermediary scripts or module loads change our current directory, restore original path, before it's locked into the window title by Set-ConsoleTitle
Set-Location $startingPath

# Sample how-to download in PowerShell, featuring a shell/console ASCII delight
# & Invoke-Expression (New-Object Net.WebClient).DownloadString('http://bit.ly/e0Mw9w')
# # Start-Sleep -Seconds 3

Write-Verbose -Message ('$HostOS = ''{0}''' -f $HostOS)

# Detect host OS and then jump to the OS specific profile sub-script

if ($IsLinux) {
    $OSProfile = (Join-Path -Path $MyScriptInfo.CommandRoot -ChildPath 'Microsoft.PowerShell_profile-Linux.ps1')
}

if ($IsMacOS) {
    $OSProfile = (Join-Path -Path $MyScriptInfo.CommandRoot -ChildPath 'Microsoft.PowerShell_profile-macOS.ps1')
}

if ($IsWindows) {
    $OSProfile = (Join-Path -Path $MyScriptInfo.CommandRoot -ChildPath 'Microsoft.PowerShell_profile-Windows.ps1')
}
Write-Output -InputObject ''
Write-Output -InputObject ' ** To view additional available modules, run: Get-Module -ListAvailable'
Write-Output -InputObject ' ** To view cmdlets available in a given module, run: Get-Command -Module <ModuleName>'

if ($IsVerbose) {Write-Output -InputObject ''}
Write-Verbose -Message ('$SubProfile = ''{0}''' -f $OSProfile)

# Load/invoke OS specific profile sub-script
if (Test-Path -Path $OSProfile) {
    # dot-source it
    . $OSProfile
    Remove-Variable -Name OSProfile -Force
} else {
    throw ('Failed to locate OS specific profile script: {0}' -f $OSProfile)
}

if ($IsVerbose) {Write-Output -InputObject ''}
Write-Output -InputObject ' # End of PowerShell $Profile CurrentUserCurrentHost #'

# For intra-profile/bootstrap script flow Testing
if ($IsVerbose) {
    Write-Output -InputObject 'Verbose testing: pausing before proceeding'
    Start-Sleep -Seconds 3
}
