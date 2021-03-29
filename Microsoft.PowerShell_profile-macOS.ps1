#!/usr/bin/env pwsh
#Requires -Version 6
#========================================
# NAME      : Microsoft.PowerShell_profile-macOS.ps1
# LANGUAGE  : Microsoft PowerShell Core
# AUTHOR    : Bryan Dady
# UPDATED   : 12/10/2018
# COMMENT   : Personal PowerShell Profile script, specific to running on a macOS host
#========================================
[CmdletBinding()]
param ()
Set-StrictMode -Version latest

# Uncomment the following 2 lines for testing profile scripts with Verbose output
#'$VerbosePreference = ''Continue'''
#$VerbosePreference = 'Continue'

Get-IsVerbose

# Region MyScriptInfo
# Only call (and use results from Get-MyScriptInfo function, if it was loaded from ./Bootstrap.ps1)
if (Test-Path -Path Function:\Get-MyScriptInfo) {
    $MyScriptInfo = Get-MyScriptInfo($MyInvocation) -Verbose

    if ($IsVerbose) { $MyScriptInfo }    
}
#End Region

Write-Output -InputObject ' # Loading PowerShell macOS Profile Script #'
Write-Verbose -Message (' ... from {0} # ' -f $MyScriptInfo.CommandPath)

$PSDefaultParameterValues = @{
    'Format-Table:autosize' = $true
    'Format-Table:wrap'     = $true
    'Get-Help:Examples'     = $true
    'Get-Help:Online'       = $true
    'Enter-PSSession:Credential'          = {Get-Variable -Name my2acct -ErrorAction Ignore}
    'Enter-PSSession:EnableNetworkAccess' = $true
    'New-PSSession:Credential'            = {Get-Variable -Name my2acct -ErrorAction Ignore}
    'New-PSSession:EnableNetworkAccess'   = $true
}

Write-Verbose -Message ' ... checking status of PSGallery ...'
# Check PSRepository status
#$PSGallery = Get-PSRepository -Name PSGallery | Select-Object -Property Name,InstallationPolicy
if ((Get-PSRepository -Name PSGallery | Select-Object -Property Name,InstallationPolicy).InstallationPolicy -ne 'Trusted') {
  Write-Output -InputObject '# Trusting PSGallery Repository #'
  Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
} else {
  Get-PSRepository
}
#Remove-Variable -Name PSGallery

Write-Debug -Message (' # # # $VerbosePreference: {0} # # #' -f $VerbosePreference)
Write-Verbose -Message 'Checking that .\scripts\ folder is available'

if ($variable:myPSScriptsPath) {
    Write-Verbose -Message ('Loading scripts from {0} ...' -f $myPSScriptsPath)
    Write-Output -InputObject ''
    $LoadScript = Join-Path -Path $myPSScriptsPath -ChildPath 'Set-ConsoleTheme.ps1'
    if (Test-Path -Path $LoadScript) {
        Write-Verbose -Message 'Initializing Set-ConsoleTheme.ps1'
        Initialize-MyScript -Path $LoadScript
        if (Get-Command -Name Set-ConsoleTheme) {
            Write-Verbose -Message 'Set-ConsoleTheme'
            Set-ConsoleTheme
        } else {
            Write-Warning -Message 'Failed to get command Set-ConsoleTheme'
        }
    } else {
        Write-Warning -Message ('Failed to initialize (dot-source) {0}' -f $LoadScript)
    }
} else {
    Write-Warning -Message ('Failed to locate Scripts folder {0}; run any scripts.' -f $myPSScriptsPath)
}

Write-Verbose -Message 'Declaring function Save-Credential'
function Save-Credential {
    [cmdletbinding(SupportsShouldProcess)]
    Param(
        [Parameter(Position = 0)]
        [string]
        $Variable = 'privileged',
        [Parameter(Position = 1)]
        [string]
        $USERNAME = $(if ($IsWindows) {$Env:USERNAME} else {$Env:USER})
    )

    $SaveCredential = $false
    Write-Verbose -Message 'Starting Save-Credential'
    $VarValueSet = [bool](Get-Variable -Name $Variable -ValueOnly -ErrorAction SilentlyContinue)
    Write-Verbose -Message ('$VarValueSet = ''{0}''' -f $VarValueSet)
    if ($VarValueSet) {
        Write-Warning -Message ('Variable ''{0}'' is already defined' -f $Variable)
        if ((read-host -prompt ('Would you like to update/replace the credential stored in {0}`? [y]|n' -f $Variable)) -ne 'y') {
            Write-Warning -Message 'Ok. Aborting Save-Credential.'
        }
    } else {
        $SaveCredential = $true
    }

    Write-Verbose -Message ('$SaveCredential = {0}' -f $SaveCredential)
    if ($SaveCredential) {

        Write-Output -InputObject ''
        Write-Output -InputObject ' # Prompting to capture elevated credentials. #'
        Write-Output -InputObject ' ...'
        Set-Variable -Name $Variable -Value $(Get-Credential -UserName $USERNAME -Message 'Store privileged credentials for convenient use later.') -Scope Global -Description 'Stored privileged credentials for convenient re-use.'
        if ($?) {
            Write-Output -InputObject ('Elevated credentials stored in variable: {0}.' -f $Variable)
        }
    }
} # end Save-Credential

New-Alias -Name rename -Value Rename-Item -ErrorAction SilentlyContinue

Write-Output -InputObject ''

if (Get-Command -Name Backup-Logs -ErrorAction SilentlyContinue) {
    # Backup local PowerShell log files
    Write-Output -InputObject 'Archive PowerShell logs'
    Backup-Logs
}

Write-Output -InputObject ' # End of PowerShell macOS Profile Script #'

# For intra-profile/bootstrap script flow Testing
if ($IsVerbose) {
    Write-Output -InputObject 'Verbose testing: pausing before proceeding'
    Start-Sleep -Seconds 3
}
