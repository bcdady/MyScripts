#!/usr/local/bin/pwsh
#Requires -Version 3
#========================================
# NAME      : Microsoft.PowerShell_profile.ps1
# LANGUAGE  : Microsoft PowerShell
# PowerShell $Profile
# Created by New-Profile function of ProfilePal module
# For more information, see https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles
#========================================
[CmdletBinding()]
param ()

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
        'CommandRoot'        = Split-Path -Path $MyCommandPath -Parent
        'CommandType'        = $MyCommandType
        'CommandModule'      = $MyCommandModule
        'ModuleName'         = $MyModuleName
        'CommandParameters'  = $MyCommandParameters.Keys
        'ParameterSets'      = $MyParameterSets
        'RemotingCapability' = $MyRemotingCapability
        'Visibility'         = $MyVisibility
    }
    $MyScriptInfo = New-Object -TypeName PSObject -Property $properties -ErrorAction SilentlyContinue
    Write-Verbose -Message ('[{0}] $MyScriptInfo populated' -f $MyInvocation.MyCommand.Name)

    # Cleanup
    foreach ($var in $properties.Keys) {
        Remove-Variable -Name ('My{0}' -f $var) -Force -ErrorAction SilentlyContinue
    }
    Remove-Variable -Name properties
    Remove-Variable -Name var

    if ($IsVerbose) {
        Write-Verbose -Message '$MyScriptInfo:'
        $Script:MyScriptInfo
    }
#End Region

# capture starting path so we can go back after other things below might move around
$startingPath = $PWD.Path

Write-Output -InputObject ' # Loading PowerShell $Profile: CurrentUserCurrentHost'

# Display PowerShell Execution Policy -- on Windows only (as ExecutionPolicy is not supported on non-Windows platforms)
if ($IsWindows) {
    Write-Output -InputObject 'Current PS execution policy is:'
    Get-ExecutionPolicy -List
}

Push-Location -Path $MyScriptInfo.CommandRoot -PassThru

# https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_prompts
function prompt {
    if ($IsWindows) {
        if (-not (Get-Variable -Name IsAdmin -ValueOnly -ErrorAction Ignore)) {
            $IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')
            if ($IsAdmin) { $AdminPrompt = '[ADMIN]:' } else { $AdminPrompt = '' }
        }
    } else {
        if (-not (Get-Variable -Name IsRoot -ValueOnly -ErrorAction Ignore)) {
            $IsRoot = ($ENV:USER -eq 'root')
            if ($IsRoot)  { $AdminPrompt = '[root]:'  } else { $AdminPrompt = '' }
        }
        $Env:COMPUTERNAME = (hostname)
    }
    if (Get-Variable -Name PSDebugContext -ValueOnly -ErrorAction Ignore) { $DebugPrompt = '[DEBUG]:' } else { $DebugPrompt = '' }
    if (Get-Variable -Name PSConsoleFile -ValueOnly -ErrorAction Ignore)  { $PSCPrompt = "[PSConsoleFile: $PSConsoleFile]" } else { $PSCPrompt = '' }
    if($NestedPromptLevel -ge 1) { $PromptLevel = 'PS .\> >' } else { $PromptLevel = 'PS .\>' }

    return "[{0} @ {1}]`n{2}{3}{4}{5}" -f $Env:COMPUTERNAME, $PWD.Path, $AdminPrompt, $PSCPrompt, $DebugPrompt, $PromptLevel
}

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

# Here's an example of how convenient aliases can be added to your PS profile
New-Alias -Name rdp -Value Start-RemoteDesktop -ErrorAction Ignore

Write-Output -InputObject ''
Write-Output -InputObject ' ** To view additional available modules, run: Get-Module -ListAvailable'
Write-Output -InputObject ' ** To view cmdlets available in a given module, run: Get-Command -Module <ModuleName>'

# Do you like easter eggs?:
#& iex (New-Object Net.WebClient).DownloadString('http://bit.ly/e0Mw9w')

# Load/invoke OS specific profile sub-script
if (Test-Path -Path $SubProfile) {
    # dot-source it
    . $SubProfile
} else {
    throw ('Failed to locate OS specific profile sub-script: {0}' -f $SubProfile)
}
Remove-Variable -Name SubProfile -Force

if ($IsVerbose) {Write-Output -InputObject ''}
Write-Output -InputObject ' # End of PowerShell $Profile CurrentUserCurrentHost #'

# For intra-profile/bootstrap script flow Testing
if ($IsVerbose) {
    Write-Output -InputObject 'Start-Sleep -Seconds 3'
    Start-Sleep -Seconds 3
}
