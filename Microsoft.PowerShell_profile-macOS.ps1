#!/usr/local/bin/pwsh
#Requires -Version 6 -module PSLogger
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
$PSGallery = Get-PSRepository -Name PSGallery | Select-Object -Property Name,InstallationPolicy
if ($PSGallery.InstallationPolicy -ne 'Trusted') {
  Write-Output -InputObject '# Trusting PSGallery Repository #'
  Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
} else {
  Get-PSRepository
}
Remove-Variable -Name PSGallery

Write-Debug -Message (' # # # $VerbosePreference: {0} # # #' -f $VerbosePreference)
Write-Verbose -Message 'Checking that .\scripts\ folder is available'

if (($variable:myPSScriptsPath) -and (Test-Path -Path $myPSScriptsPath -PathType Container)) {
    Write-Verbose -Message ('Loading scripts from {0} ...' -f $myPSScriptsPath)
    Write-Output -InputObject ''

    Write-Verbose -Message 'Initializing Set-ConsoleTheme.ps1'
    . (Join-Path -Path $myScriptsPath -ChildPath 'Set-ConsoleTheme.ps1')
    Write-Verbose -Message 'Set-ConsoleTheme'
    Set-ConsoleTheme

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

# Backup local PowerShell log files
Write-Output -InputObject 'Archive PowerShell logs'
Backup-Logs
# Write-Output -InputObject ('$VerbosePreference: {0} is {1}' -f $VerbosePreference, $IsVerbose)

Write-Output -InputObject ' # End of PowerShell macOS Profile Script #'

<#
    # For intra-profile/bootstrap script flow Testing
    Write-Output -InputObject ''
    Start-Sleep -Seconds 3
#>
