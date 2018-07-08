#!/usr/local/bin/pwsh
#Requires -Version 3 -module PSLogger
#========================================
# NAME      : Microsoft.PowerShell_profile.ps1
# LANGUAGE  : Microsoft PowerShell
# PowerShell $Profile
# Created by New-Profile function of ProfilePal module
# For more information, see https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles
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
    Write-Verbose -Message '[CurrentUserCurrentHost Profile] Populating $MyScriptInfo'
    $Private:MyCommandName        = $MyInvocation.MyCommand.Name
    $Private:MyCommandPath        = $MyInvocation.MyCommand.Path
    $Private:MyCommandType        = $MyInvocation.MyCommand.CommandType
    $Private:MyCommandModule      = $MyInvocation.MyCommand.Module
    $Private:MyModuleName         = $MyInvocation.MyCommand.ModuleName
    $Private:MyCommandParameters  = $MyInvocation.MyCommand.Parameters
    $Private:MyParameterSets      = $MyInvocation.MyCommand.ParameterSets
    $Private:MyRemotingCapability = $MyInvocation.MyCommand.RemotingCapability
    $Private:MyVisibility         = $MyInvocation.MyCommand.Visibility

    if (($null -eq $Private:MyCommandName) -or ($null -eq $Private:MyCommandPath)) {
        # We didn't get a successful command / script name or path from $MyInvocation, so check with CallStack
        Write-Verbose -Message 'Getting PSCallStack [$CallStack = Get-PSCallStack]'
        $Private:CallStack        = Get-PSCallStack | Select-Object -First 1
        $Private:MyScriptName     = $Private:CallStack.ScriptName
        $Private:MyCommand        = $Private:CallStack.Command
        Write-Verbose -Message ('$MyScriptName: {0}' -f $Private:MyScriptName)
        Write-Verbose -Message ('$MyCommand: {0}' -f $Private:MyCommand)
        Write-Verbose -Message 'Assigning previously null MyCommand variables with CallStack values'
        $Private:MyCommandPath    = $Private:MyScriptName
        $Private:MyCommandName    = $Private:MyCommand
    }

    #'Optimize New-Object invocation, based on Don Jones' recommendation: https://technet.microsoft.com/en-us/magazine/hh750381.aspx
    $Private:properties = [ordered]@{
        'CommandName'        = $Private:MyCommandName
        'CommandPath'        = $Private:MyCommandPath
        'CommandType'        = $Private:MyCommandType
        'CommandModule'      = $Private:MyCommandModule
        'ModuleName'         = $Private:MyModuleName
        'CommandParameters'  = $Private:MyCommandParameters.Keys
        'ParameterSets'      = $Private:MyParameterSets
        'RemotingCapability' = $Private:MyRemotingCapability
        'Visibility'         = $Private:MyVisibility
    }
    $MyScriptInfo = New-Object -TypeName PSObject -Property $Private:properties
    Write-Verbose -Message '[CurrentUserCurrentHost Profile] $MyScriptInfo populated'

    # Cleanup
    foreach ($var in $Private:properties.Keys) {
        Remove-Variable -Name ('My{0}' -f $var) -Force
    }

    if ($IsVerbose) {
        Write-Verbose -Message '$MyScriptInfo:'
        $Script:MyScriptInfo
    }
#End Region

Write-Output -InputObject ' # Loading PowerShell $Profile CurrentUserCurrentHost #'
Write-Verbose -Message (' ... from {0} # ' -f $MyScriptInfo.CommandPath)

# https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_prompts
if ($IsVerbose) {Write-Output -InputObject ''}
Write-Verbose -Message 'Defining custom prompt'
function prompt {
    if (-not (Get-Variable -Name IsAdmin -ValueOnly -ErrorAction SilentlyContinue)) {
        # $IsWindows, if not already provided by pwsh $Host, is set in bootstrap.ps1
        if ($IsWindows) {
            $IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')
        }
    }
    if ( $IsAdmin ) { $AdminPrompt = '[ADMIN]:' } else { $AdminPrompt = '' }
    if ( Get-Variable -Name PSDebugContext -ValueOnly -ErrorAction SilentlyContinue) { $DebugPrompt = '[DEBUG]:' } else { $DebugPrompt = '' }
    if ( Get-Variable -Name PSConsoleFile -ValueOnly -ErrorAction SilentlyContinue)  { $PSCPrompt = "[PSConsoleFile: $PSConsoleFile]" } else { $PSCPrompt = '' }
    if ( $NestedPromptLevel -ge 1 ) { $PromptLevel = 'PS .\> >' } else { $PromptLevel = 'PS .\>' }

    return "[{0} @ {1}]`n{2}{3}{4}{5}" -f $Env:ComputerName, $pwd.Path, $AdminPrompt, $PSCPrompt, $DebugPrompt, $PromptLevel
}
if ($IsVerbose) {Write-Output -InputObject ''}

#Region Bootstrap
    # Moved HOME / MyPSHome, Modules, and Scripts variable determination to bootstrap script
    Write-Verbose -Message ('(Get-Variable -Name ''myPSHome'' -ErrorAction SilentlyContinue) // Already bootstrapped? = ''{0}''' -f [bool](Get-Variable -Name 'myPSHome' -ErrorAction SilentlyContinue))
    Write-Verbose -Message ('(Split-Path -Path $MyScriptInfo.CommandPath) = ''{0}''' -f (Split-Path -Path $MyScriptInfo.CommandPath))
    Write-Verbose -Message ('(Test-Path -Path (Join-Path -Path (split-path -Path $MyScriptInfo.CommandPath) -ChildPath ''bootstrap.ps1'') = ''{0}''' -f (Test-Path -Path (Join-Path -Path(Split-Path -Path $MyScriptInfo.CommandPath) -ChildPath 'bootstrap.ps1')))

    if (Get-Variable -Name 'myPSHome' -ErrorAction SilentlyContinue) {
        if ($IsVerbose) {Write-Output -InputObject ''}
        Write-Verbose -Message 'This PS Session was previously bootstrapped'
    } else {
        # Load/invoke bootstrap
        if (Test-Path -Path (Join-Path -Path (split-path -Path $MyScriptInfo.CommandPath) -ChildPath 'bootstrap.ps1')) {
            . (Join-Path -Path (split-path -Path $MyScriptInfo.CommandPath) -ChildPath 'bootstrap.ps1')

            if (Get-Variable -Name 'myPS*' -ValueOnly -ErrorAction SilentlyContinue) {
                Write-Output -InputObject ''
                Write-Output -InputObject 'My PowerShell Environment:'
                Get-Variable -Name 'myPS*' | Format-Table
            } else {
                if ($IsVerbose) {Write-Output -InputObject ''}
                Write-Warning -Message ' # !! Failed to verify My PowerShell Environment was initialized by bootstrap script. !! #'
                throw ('Failed to bootstrap: {0}\bootstrap.ps1' -f (Split-Path -Path $MyScriptInfo.CommandPath))
            }
        } else {
            if ($IsVerbose) {Write-Output -InputObject ''}
            Write-Warning -Message ' # !! Expected PowerShell Environment bootstrap script was not found. !! #'
            throw ('Failed to bootstrap: {0}\bootstrap.ps1' -f (Split-Path -Path $MyScriptInfo.CommandPath))
        }
    }
#End Region

<# Yes! This even works in XenApp!
    & Invoke-Expression (New-Object Net.WebClient).DownloadString('http://bit.ly/e0Mw9w')
    # start-sleep -Seconds 3
#>
# Call Set-ConsoleTitle, from ProfilePal module
if ($IsVerbose) {Write-Output -InputObject ''}
Write-Verbose -Message ' # Set-ConsoleTitle >'
Set-ConsoleTitle
Write-Verbose -Message ' # < Set-ConsoleTitle'
if ($IsVerbose) {Write-Output -InputObject ''}

# Display execution policy, for convenience
Write-Output -InputObject 'PowerShell Execution Policy: '
Get-ExecutionPolicy -List | Format-Table -AutoSize

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
if (Test-Path -Path $Private:SubProfile) {
    # dot-source it
    . $Private:SubProfile
} else {
    throw ('Failed to locate OS specific profile sub-script: {0}' -f $Private:SubProfile)
}

if ($IsVerbose) {Write-Output -InputObject ''}
Write-Output -InputObject ' # End of PowerShell $Profile CurrentUserCurrentHost #'

<#
    # For intra-profile/bootstrap script flow Testing
    Write-Output -InputObject ''
    Start-Sleep -Seconds 3
#>