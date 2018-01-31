#requires -Version 3
#===============================================================================
# NAME      : Setup_my_VSCode.ps1
# LANGUAGE  : Windows PowerShell
# AUTHOR    : Bryan Dady
# DATE      : 06/22/2017
# COMMENT   : R:\IT\Microsoft Tools\VS Code editor\Setup_my_VSCode.ps1 sets up Microsoft Visual Studio code (VS code), as an alternative to the .exe Setup
#           : The parent 'VS Code editor' folder should contain:
#           : - a \.vscode\ folder with select VS code extensions
#           : - a \scripts\ folder containing Open-PSEdit.ps1 and Save-VSCodePrefs.ps1
#           : - a \User\ folder with any of settings.json, keybindings.json and \snippets\
#           : - a \VScode\ folder containing the extracted files of the latest available 'VSCode-winXX-VerNum' zip archive
#===============================================================================
[CmdletBinding(SupportsShouldProcess)]
param ()
Set-StrictMode -Version latest

Write-Verbose -Message 'Setting up transcript/logging'
if (-not (Test-Path -Path (Join-Path -Path $(Split-Path -Path $MyInvocation.MyCommand.Path -Parent) -ChildPath 'log'))) {
    New-Item -Path (Join-Path -Path $(Split-Path -Path $MyInvocation.MyCommand.Path -Parent) -ChildPath 'log') -ItemType Container
}

Start-Transcript -Path $(Join-Path -Path (Join-Path -Path $(Split-Path -Path $MyInvocation.MyCommand.Path -Parent) -ChildPath 'log') -ChildPath "VSCode_Setup_$Env:USERNAME`_$(Get-Date -UFormat "%Y%m%d").log") -Append

$Home_VScode = Join-Path -Path $HOME -ChildPath 'VSCode'
"`nSetting up Microsoft Visual Studio code (VS code) ... "
"Copying Visual Studio Code (ver 1.13.1) to $Home_VScode"
"Robocopy ""R:\IT\Microsoft Tools\VS Code editor\VSCode\VSCode-win32-ia32"" ""$Home_VScode"""
 & Robocopy.exe """R:\IT\Microsoft Tools\VS Code editor\VSCode\VSCode-win32-ia32"" ""$Home_VScode"" /MIR /MT /DST /R:10 /W:10 /DST /MT /NFL /ETA /LOG+:$HOME\VSCode-copy.log"

"Copying VS Code extensions to $HOME\.vscode\extensions"
"Robocopy ""R:\IT\Microsoft Tools\VS Code editor\.vscode\extensions"" ""(Join-Path -Path $HOME -ChildPath '.vscode\extensions')"""
& Robocopy.exe """R:\IT\Microsoft Tools\VS Code editor\.vscode\extensions"" ""(Join-Path -Path $HOME -ChildPath '.vscode\extensions')"" /MIR /MT /DST /R:10 /W:10 /DST /MT /NFL /ETA  /LOG+:$HOME\VSCode-copy.log"

"Copying VS Code user settings sync and personalization script to users `$HOME"
"Robocopy ""R:\IT\Microsoft Tools\VS Code editor\User"" ""$Home_VScode\User"""
& Robocopy.exe """R:\IT\Microsoft Tools\VS Code editor\User"" ""$Home_VScode\User"" /MIR /MT /DST /R:10 /W:10 /DST /MT /NFL /ETA /LOG+:$HOME\VSCode-copy.log"

# Copy this following section / region to your PowerShell Profile ($PROFILE)
#Region CodeSetup
    "Starting VS Code setup"
    . 'R:\IT\Microsoft Tools\VS Code editor\scripts\Save-VSCodePrefs.ps1'
    "Restore-VSCodePrefs ... "
    Restore-VSCodePrefs

    $PSEdit = Join-Path -Path (Join-Path -Path $env:HOMEDRIVE -ChildPath '*\WindowsPowerShell' -Resolve) -ChildPath 'scripts\Open-PSEdit.ps1' -Resolve
    if (Test-Path -Path $PSEdit -PathType Leaf) {
        "Setting up environment to be VS code aware (Open-PSEdit.ps1)"
        . $PSEdit
        Start-Sleep -Milliseconds 500
        if (Test-Path -Path $Home_VScode\bin\code.cmd -PathType Leaf) {
            Assert-PSEdit -Path $Home_VScode\bin\code.cmd -v
        } else {
            Write-Warning -Message "Attempted Assert-PSEdit -Path $Home_VScode\bin\code.cmd, that path was not found."
        }
        "`nGet-PSEdit:"
        Get-PSEdit
    } else {
        Write-Warning -Message "Attempted Setup VS code environment via Open-PSEdit, but `$PSEdit was not found ($PSEdit)."
    }
#End Region 

Stop-Transcript

"`n# # # The End # # #`n"
"You're now setup with your own copy of VS Code, with suggested extensions and settings. For quick launch of VS Code in the future (from $Home_VScode), you should add references to the new Save-VSCodePrefs, Restore-VSCodePrefs, and *-PSedit functions to your PowerShell Profile."
"`nIf you don't yet have a PowerShell `$PROFILE script, check with Bryan for help getting started, and/or checkout the ProfilePal module at (R:\IT\PowerShell-Modules\ProfilePal)."

"Open-PSEdit"
Open-PSEdit