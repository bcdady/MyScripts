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

<#
    Write-Debug -Message 'Detect -Verbose $VerbosePreference'
    switch ($VerbosePreference) {
        Stop             { $IsVerbose = $True }
        Inquire          { $IsVerbose = $True }
        Continue         { $IsVerbose = $True }
        SilentlyContinue { $IsVerbose = $False }
        Default          { $IsVerbose = $False }
    }
    Write-Debug -Message ('$VerbosePreference: {0} is {1}' -f $VerbosePreference, $IsVerbose)

    # For testing: Set Verbose host output Preference
    $VerbosePreference = 'Inquire'
    '$IsVerbose'
    $IsVerbose
#>

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
        $Private:CallStack = Get-PSCallStack | Select-Object -First 1
        # $Private:CallStack | Select Position, ScriptName, Command | format-list # FunctionName, ScriptLineNumber, Arguments, Location
        $Private:MyScriptName = $Private:CallStack.ScriptName
        $Private:MyCommand = $Private:CallStack.Command
        Write-Verbose -Message "`$ScriptName: $Private:MyScriptName"
        Write-Verbose -Message "`$Command: $Private:MyCommand"
        Write-Verbose -Message 'Assigning previously null MyCommand variables with CallStack values'
        $Private:MyCommandPath = $Private:MyScriptName
        $Private:MyCommandName = $Private:MyCommand
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

    $IsVerbose = $false
    if ('Verbose' -in $PSBoundParameters.Keys) {
        Write-Verbose -Message 'Output Level is [Verbose]. $MyScriptInfo is:'
        $IsVerbose = $true
        $Script:MyScriptInfo
    }
#End Region

Write-Output -InputObject ' # Loading PowerShell $Profile CurrentUserCurrentHost #'
Write-Verbose -Message (' ... from {0} # ' -f $MyScriptInfo.CommandPath)

# https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_prompts
Write-Verbose -Message 'Defining custom prompt'
function prompt {
    if (-not (Get-Variable -Name IsAdmin -ValueOnly -ErrorAction Ignore)) {
        $IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')
    }
    if ( $IsAdmin ) { $AdminPrompt = '[ADMIN]:' } else { $AdminPrompt = '' }
    if ( Get-Variable -Name PSDebugContext -ValueOnly -ErrorAction Ignore) { $DebugPrompt = '[DEBUG]:' } else { $DebugPrompt = '' }
    if ( Get-Variable -Name PSConsoleFile -ValueOnly -ErrorAction Ignore)  { $PSCPrompt = "[PSConsoleFile: $PSConsoleFile]" } else { $PSCPrompt = '' }
    if ( $NestedPromptLevel -ge 1 ) { $PromptLevel = 'PS .\> >' } else { $PromptLevel = 'PS .\>' }

    return "[{0} @ {1}]`n{2}{3}{4}{5}" -f $Env:ComputerName, $pwd.Path, $AdminPrompt, $PSCPrompt, $DebugPrompt, $PromptLevel
}

#Region Bootstrap
    # Moved HOME / MyPSHome, Modules, and Scripts variable determination to bootstrap script
    Write-Verbose -Message '(Get-Variable -Name "myPSHome" -ErrorAction Ignore)'
    Write-Verbose -Message "$([bool](Get-Variable -Name 'myPSHome' -ErrorAction Ignore))"
    Write-Verbose -Message '(Test-Path -Path (Join-Path -Path (split-path -Path $MyScriptInfo.CommandPath) -ChildPath "bootstrap.ps1"))'
    Write-Verbose -Message (Test-Path -Path (Join-Path -Path (split-path -Path $MyScriptInfo.CommandPath) -ChildPath 'bootstrap.ps1'))
        
    Write-Verbose -Message '(((-not (Get-Variable -Name ''myPSHome'' -ErrorAction Ignore))) -and (Test-Path -Path (Join-Path -Path (split-path -Path $MyScriptInfo.CommandPath) -ChildPath ''bootstrap.ps1'')))'
    Write-Verbose -Message (((-not (Get-Variable -Name 'myPSHome' -ErrorAction Ignore))) -and (Test-Path -Path (Join-Path -Path (split-path -Path $MyScriptInfo.CommandPath) -ChildPath "bootstrap.ps1")))

    if (Get-Variable -Name 'myPSHome' -ErrorAction Ignore) {
        Write-Verbose -Message 'This PS Session was previously bootstrapped'
    } else {
        # Load/invoke bootstrap
        if (Test-Path -Path (Join-Path -Path (split-path -Path $MyScriptInfo.CommandPath) -ChildPath 'bootstrap.ps1')) {
            . (Join-Path -Path (split-path -Path $MyScriptInfo.CommandPath) -ChildPath 'bootstrap.ps1')

            if (Get-Variable -Name 'myPS*' -ValueOnly -ErrorAction Ignore) {
                Write-Output -InputObject ''
                Write-Output -InputObject 'My PowerShell Environment:'
                Get-Variable -Name 'myPS*' | Format-Table
            } else {
                Write-Warning -Message ('Failed to enumerate My PowerShell Environment as should have been initialized by bootstrap script: {0}' -f ((Join-Path -Path (split-path -Path $MyScriptInfo.CommandPath) -ChildPath 'bootstrap.ps1')))
            }
        } else {
            throw ('Failed to bootstrap: {0}\bootstrap.ps1' -f $Private:MyCommandPath)
        }
    }
#End Region  

<# Yes! This even works in XenApp!
    & Invoke-Expression (New-Object Net.WebClient).DownloadString('http://bit.ly/e0Mw9w')
    # start-sleep -Seconds 3
#>
# Call Set-ConsoleTitle, from ProfilePal module
Set-ConsoleTitle

# Display execution policy, for convenience
Write-Output -InputObject 'PowerShell Execution Policy: '
Get-ExecutionPolicy -List | Format-Table -AutoSize

# Detect host OS and then jump to the OS specific profile sub-script
if ($IsLinux) {
    $Private:SubProfile = (Join-Path -Path (split-path -Path $MyScriptInfo.CommandPath) -ChildPath 'Microsoft.PowerShell_profile-Linux.ps1')
    #Test-Path -Path $myPSHome\Microsoft.PowerShell_profile-Linux.ps1
}

if ($IsMacOS) {
    $Private:SubProfile = (Join-Path -Path (split-path -Path $MyScriptInfo.CommandPath) -ChildPath 'Microsoft.PowerShell_profile-macOS.ps1')
    #Test-Path -Path $myPSHome\Microsoft.PowerShell_profile-macOS.ps1
}

if ($IsWindows) {
    $Private:SubProfile = (Join-Path -Path (split-path -Path $MyScriptInfo.CommandPath) -ChildPath 'Microsoft.PowerShell_profile-Windows.ps1')
    #Test-Path -Path $myPSHome\Microsoft.PowerShell_profile-Windows.ps1
}

# Load/invoke OS specific profile sub-script
if (Test-Path -Path $Private:SubProfile) {
    # dot-source it
    . $Private:SubProfile
} else {
    throw ('Failed to locate OS specific profile sub-script: {0}' -f $Private:SubProfile)
}

Write-Output -InputObject ' # End of PowerShell $Profile CurrentUserCurrentHost #'

<#
    # For intra-profile/bootstrap script flow Testing
    Write-Output -InputObject ''
    Start-Sleep -Seconds 3
#>