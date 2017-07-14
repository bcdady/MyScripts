#requires -Version 3
#===============================================================================
# NAME      : Save-VSCodePrefs.ps1
# LANGUAGE  : Windows PowerShell
# AUTHOR    : Bryan Dady
# DATE      : 06/22/2017
# COMMENT   : Save (backup) and Restore User Preferences / Settings (json) files for Visual Studio Code editor
#===============================================================================
[CmdletBinding(SupportsShouldProcess)]
param ()
Set-StrictMode -Version latest
#===============================================================================
#Region MyScriptInfo
    Write-Verbose -Message '[VSCodePrefs] Populating $MyScriptInfo'
    $script:MyCommandName       = $MyInvocation.MyCommand.Name
    $script:MyCommandPath       = $MyInvocation.MyCommand.Path
    $script:MyCommandType       = $MyInvocation.MyCommand.CommandType
    $script:MyCommandModule     = $MyInvocation.MyCommand.Module
    $script:MyModuleName        = $MyInvocation.MyCommand.ModuleName
    $script:MyCommandParameters = $MyInvocation.MyCommand.Parameters
    $script:MyParameterSets     = $MyInvocation.MyCommand.ParameterSets
    $script:MyRemotingCapability = $MyInvocation.MyCommand.RemotingCapability
    $script:MyVisibility        = $MyInvocation.MyCommand.Visibility

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
        'CommandName'        = $($script:MyCommandName.Split('.'))[0]
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
    Write-Verbose -Message '[VSCodePrefs] $MyScriptInfo populated'
#End Region

#Derive $logBase from script name ($MyScriptInfo.CommandName)
# But the value of this variable changes within Functions, so we define a shared logging base from the 'parent' script file (name) level
# all logging cmdlets later throughout this script should derive their logging path from this $logBase directory, by appending simply .log, or preferable [date].log
if (-not [bool](Get-Variable -Name myPSHome -Scope Global -ErrorAction Ignore))
{
    Write-Verbose -Message "Set `$script:myPSHome to $(Join-Path -Path "$([Environment]::GetFolderPath('MyDocuments'))" -ChildPath 'WindowsPowerShell')"
    $script:myPSHome = Join-Path -Path "$([Environment]::GetFolderPath('MyDocuments'))" -ChildPath 'WindowsPowerShell'
}

if ($myPSHome -match "$env:SystemDrive") {
    Write-Verbose -Message "Set `$script:localPSHome to $myPSHome"
    $script:localPSHome = $myPSHome
}

# In case %HOMEDRIVE% appears to be local, try to use a 'default network home share drive "h"
if (Test-Path -Path 'H:') {
    Write-Verbose -Message "Set `$script:netPSHome to $(Join-Path -Path 'H:' -ChildPath '*\WindowsPowerShell' -Resolve)"
    $script:netPSHome = Join-Path -Path 'H:' -ChildPath '*\WindowsPowerShell' -Resolve
} else {
    $script:netPSHome = $null
}

# If %HOMEDRIVE% does not match %SystemDrive%, then it's a network drive, so use that 
if ($env:HOMEDRIVE -ne $env:SystemDrive) {
    if (Test-Path -Path $env:HOMEDRIVE) {
        Write-Verbose -Message "Set `$script:netPSHome to `$env:HOMEDRIVE ($env:HOMEDRIVE)"
        $script:netPSHome = Join-Path -Path $env:HOMEDRIVE -ChildPath '*\WindowsPowerShell' -Resolve
    }
}

$script:logFileBase = $(Join-Path -Path $myPSHome -ChildPath 'log')

Write-Verbose -Message " Dot-Sourcing $($MyScriptInfo.CommandPath)"

Write-Debug -Message "  ... logFileBase is $script:logFileBase\$($MyScriptInfo.CommandName)-[date].log"

Write-Verbose -Message "Declaring Function Save-VSCodePrefs"
function Save-VSCodePrefs {
    <#
        .SYNOPSIS
            Backup ephemeral Visual Studio Code preferences (user settings and extensions) from current working environment (OS), to a repository, from which it can be later restored.
        .DESCRIPTION
            
        .PARAMETER Path
            Optionally specifies the 'root' path of where to copy VS Code user files to
        .EXAMPLE
            PS .\> Save-VSCodePrefs

            Copies files from $Env:APPDATA\Code\User to the specified $Path.
            Default $Path is $HOME\VSCode\User
        .NOTES
            VERSION     :  0.1.0
            LAST UPDATED:  06/23/2017
            AUTHOR      :  Bryan Dady
    #>
    [cmdletbinding()]
    param (
        [Parameter(Position=0)]
        [ValidateScript({Test-Path -Path $PSItem -PathType Container})]
        [string]
        $Path = "$(Join-Path -Path $HOME -ChildPath 'VSCode\User')"
    )

    "Checking `$path: $path"

    if (Test-Path -Path $Env:APPDATA\Code\User) {
        # confirmed source path exists
        'Confirmed source path folder exists ($Env:APPDATA\Code\User)'
    } else {
        # source path doesn't yet exist
        'Source path $Env:APPDATA\Code\User not found.'
        throw "Source path $Env:APPDATA\Code\User not found."
    }
    
    if (Test-Path -Path "$path") {
        # confirmed $path exists
        'Confirmed `$path folder exists'
    } else {
        # $path doesn't yet exist, so create it
        "Creating folder: $Path"
        New-Item -ItemType Directory -Path $path
    }

    # we can now proceed with copying files
    " # # # BEGIN ROBOCOPY # # # # #`n"

    "Robocopy ""$Env:APPDATA\Code\User"" ""$Path"""
    & robocopy.exe """$Env:APPDATA\Code\User"" ""$Path"" /MIR /R:10 /W:10"

    " # # # END ROBOCOPY # # # # #`n"

} # end Save-VSCodePrefs

New-Alias -Name Backup-VSCodePrefs -Value Save-VSCodePrefs -Force

Write-Verbose -Message "Declaring Function Restore-VSCodePrefs"
function Restore-VSCodePrefs {
    <#
        .SYNOPSIS
            Restore Visual Studio Code preferences (user settings and extensions) from where they were previously saved by the Restore-VSCodePrefs, to the current working environment (OS).
        .DESCRIPTION
            
        .PARAMETER Path
            Optionally specifies the 'root' path of where to copy VS Code user files
        .EXAMPLE
            PS .\> Restore-VSCodePrefs

            Copies files from the specified $Path to $Env:APPDATA\Code\User.
            Default $Path is $HOME\VSCode\User
        .NOTES
            VERSION     :  0.1.0
            LAST UPDATED:  06/23/2017
            AUTHOR      :  Bryan Dady
    #>
    [cmdletbinding()]
    param (
        [Parameter(Position=0)]
        [ValidateScript({Test-Path -Path $PSItem -PathType Container})]
        [string]
        $Path = "$(Join-Path -Path $HOME -ChildPath 'VSCode\User')"
    )

    "Checking `$path: $path"

    if (Test-Path -Path "$path") {
        # confirmed $path exists
        "Confirmed $path is available"
    } else {
        # $path doesn't yet exist, so create it
        $VSSettingsSource = (Resolve-Path -Path 'R:\IT\Microsoft Tools\VS Code editor\User' -ErrorAction 'Stop')
        "VS Code Settings not found at $Path. Getting settings files from shared source: $($VSSettingsSource.Path)"

        try {
            $PSscripts = (Join-Path -Path $(Resolve-Path -Path "$HOME*\WindowsPowerShell") -ChildPath 'scripts')
            "Copying VS Code user settings sync and personalization script to $PSscripts"
            Robocopy """R:\IT\Microsoft Tools\VS Code editor\scripts"" ""$PSscripts"" /MT /DST /R:10 /W:10 /NFL /NDL /ETA /LOG+:$HOME\VSCode-ext-copy.log"
        }
        catch {
            Write-Warning -Message 'Failed to locate PowerShell Scripts folder under $HOME. Unable to setup personal copies of Restore-VSCodePrefs and Open-PSedit.'
        }
    }

    if (Test-Path -Path $Env:APPDATA\Code\User) {
        # confirmed target path exists
        'Confirmed target path folder exists ($Env:APPDATA\Code\User)'
        Write-Warning -Message "Confirmed target path folder exists. Contents of $Env:APPDATA\Code\User may be overwritten.`nType Ctrl+c to abort."
        Start-Sleep -Seconds 5
    }

    # we can now proceed with copying files
    'Copying Visual Studio Code extensions to $HOME\.vscode\extensions'
    "Robocopy ""$(Join-Path -Path $HOME -ChildPath '.vscode\extensions')"" ""$(Join-Path -Path $Env:USERPROFILE -ChildPath '.vscode\extensions')"""
    & robocopy.exe """$(Join-Path -Path $HOME -ChildPath '.vscode\extensions')"" ""$(Join-Path -Path $Env:USERPROFILE -ChildPath '.vscode\extensions')"" /DST /NDL /NFL /MIR /XD logs /NP /ETA /MT:8 /R:10 /W:10"

    'Copying Visual Studio Code user preferences settings'
    "Robocopy ""$Path"" ""$Env:APPDATA\Code\User"""
    & robocopy.exe """$Path"" ""$Env:APPDATA\Code\User"" /DST /NDL /NFL /E /COPY:DAT /NP /ETA /MT:8 /R:10 /W:10"

} # end Restore-VSCodePrefs

New-Alias -Name Copy-VSCodePrefs -Value Restore-VSCodePrefs -Force