#!/usr/local/bin/powershell
#Requires -Version 2

[CmdletBinding()]
Param()
Set-StrictMode -Version latest

#Region MyScriptInfo
  Write-Verbose -Message '[Open-PSEdit] Populating $MyScriptInfo'
  $script:MyCommandName = $MyInvocation.MyCommand.Name
  $script:MyCommandPath = $MyInvocation.MyCommand.Path
  $script:MyCommandType = $MyInvocation.MyCommand.CommandType
  $script:MyCommandModule = $MyInvocation.MyCommand.Module
  $script:MyModuleName = $MyInvocation.MyCommand.ModuleName
  $script:MyCommandParameters = $MyInvocation.MyCommand.Parameters
  $script:MyParameterSets = $MyInvocation.MyCommand.ParameterSets
  $script:MyRemotingCapability = $MyInvocation.MyCommand.RemotingCapability
  $script:MyVisibility = $MyInvocation.MyCommand.Visibility

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
    'CommandName'        = $script:MyCommandName
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
  Write-Verbose -Message '[Open-PSEdit] $MyScriptInfo populated'
#End Region

# Detect older versions of PowerShell and add in new automatic variables for more cross-platform consistency
if ($Host.Version.Major -le 5) {
  $Global:IsWindows = $true
  $Global:PSEdition = 'Native'
}

Write-Output -InputObject 'Ensure this script is dot-sourced, to get access to it''s contained functions'

# dot-source script file containing Add-PATH and related helper functions
$RelativePath = Split-Path -Path (Resolve-Path -Path $MyScriptInfo.CommandPath -Relative) -Parent
Write-Verbose -Message "Initializing $RelativePath\Edit-Path.ps1" -Verbose
. $RelativePath\Edit-Path.ps1

Write-Verbose -Message 'Declaring Function Get-PSEdit'
Function Get-PSEdit {
    Write-Verbose -Message 'Getting environment variable PSEdit'
    if ($Env:PSEdit) {
        return $Env:PSEdit
    }
    # Get-ChildItem Env:PSEdit -ErrorAction SilentlyContinue | Format-List
    #if (!$?) {
    else {
        Write-Output -InputObject "Env:PSEdit is Undefined.`nRun Assert-PSEdit to declare or detect Path to available editor."
    }
}

Write-Verbose -Message 'Declaring Function Assert-PSEdit'
Function Assert-PSEdit {
    [CmdletBinding()]
    Param (
        [Parameter(Position=0)]
        [ValidateScript({Test-Path -Path (Resolve-Path -Path $PSItem)})]
        $Path = (Resolve-Path -Path $HOME\VSCode\bin\code.cmd)
    )

    if ($Env:PSEdit) {
        if (Test-Path -Path $Env:PSEdit) {
            Write-Warning -Message "`$Env:PSEdit is currently defined as $Env:PSEdit"
        } else {
            Write-Warning -Message "`$Env:PSEdit is currently pointed at invalid Path: $Env:PSEdit"
        }
    }

    Write-Verbose -Message 'Asking OS for an available instance of VS Code'
    $vscode = $null
    if (-not $IsWindows) {
        Write-Verbose -Message 'Detected NOT Windows OS. Checking for result from ''which code'''
        # Ask host os for the path to Visual Studio Code (via which binary/exe)
        $ErrorActionPreference = 'SilentlyContinue'
        $vscode = Resolve-Path -Path (which code) -ErrorAction SilentlyContinue
        $ErrorActionPreference = 'Continue'
    } else {
        Write-Verbose -Message 'Detected Windows OS. Checking for  a match to ''VS Code'' in PATH'
        # Look for default install path of "...\Microsoft VS Code\..." in Environment PATH
        if ($Env:PATH -split ';' | select-string -Pattern 'VS Code') {
            Write-Verbose -Message 'An entry matching ''VS Code'' was found in the PATH variable'
            $vscode = Join-Path -Path ($Env:PATH -split ';' | select-string -Pattern 'VS Code' | Select-Object -Property Line).Line -ChildPath 'code.cmd' -Resolve
            Write-Verbose -Message "Derived $vscode from the PATH"
        } else {
            Write-Verbose -Message 'VS Code NOT found ... Checking if ISE is available'
            $PSISE = Join-Path -Path $PSHOME -ChildPath 'powershell_ise.exe' -Resolve
            if (Test-Path -Path $PSISE -PathType Leaf) {
                Write-Verbose -Message 'Detected PS ISE is installed.'
            }
        }
    }   

    if ($null -ne $vscode) {
        Write-Verbose -Message "Setting `$Env:PSEdit to `$vscode: $vscode"
        $Env:PSEdit = $vscode
    # Write-Debug -Message 'Failed to locate an available instance of VS code'
    } elseif (Test-Path -Path $(Resolve-Path -Path $Path) -PathType Leaf) {
            $Path = Resolve-Path -Path $Path
            Write-Verbose -Message "Setting `$Env:PSEdit to Path (Parameter): $Path"
            $Env:PSEdit = $Path
        # } else {
        #     throw "Fatal error testing Path Parameter $Path"
    } elseif ($PSISE) {
        Write-Verbose -Message "Setting `$Env:PSEdit to $PSISE"
        $Env:PSEdit = $PSISE
    }

    # Check and update $Env:PATH to include path to code; some code extensions look for code in the PATH
    Write-Verbose -Message "Adding $(Split-Path -Path $Env:PSEdit -Parent -Resolve) to `$Env:PATH"
    # Send output from Add-Path to Null, so we don't have to read $Env:Path in the console
    Add-Path (Split-Path -Path $Env:PSEdit -Parent -Resolve) | Out-Null
    return $Env:PSEdit
}

Write-Verbose -Message 'Declaring Function Open-PSEdit'
function Open-PSEdit {
    <#
        Potential enhancements, as examples of code.exe / code-insiders.exe parameters
        --install-extension guosong.vscode-util --install-extension ms-vscode.PowerShell --install-extension Shan.code-settings-sync --install-extension wmaurer.change-case --install-extension DavidAnson.vscode-markdownlint
        --install-extension LaurentTreguier.vscode-simple-icons --install-extension seanmcbreen.Spell --install-extension mohsen1.prettify-json --install-extension ms-vscode.Theme-MarkdownKit 

        Visual Studio Code - Insiders 1.8.0-insider

        Usage: code-insiders.exe [options] [paths...]

        Options:
        -d, --diff                  Open a diff editor. Requires to pass two file
                                    paths as arguments.
        -g, --goto                  Open the file at path at the line and column (add
                                    :line[:column] to path).
        --locale <locale>           The locale to use (e.g. en-US or zh-TW).
        -n, --new-window            Force a new instance of Code.
        -p, --performance           Start with the 'Developer: Startup Performance'
                                    command enabled.
        -r, --reuse-window          Force opening a file or folder in the last active
                                    window.
        --user-data-dir <dir>       Specifies the directory that user data is kept
                                    in, useful when running as root.
        --verbose                   Print verbose output (implies --wait).
        -w, --wait                  Wait for the window to be closed before
                                    returning.
        --extensions-dir <dir>      Set the root path for extensions.
        --list-extensions           List the installed extensions.
        --show-versions             Show versions of installed extensions, when using
                                    --list-extension.
        --install-extension <ext>   Installs an extension.
        --uninstall-extension <ext> Uninstalls an extension.
        --disable-extensions        Disable all installed extensions.
        --disable-gpu               Disable GPU hardware acceleration.
        -v, --version               Print version.
        -h, --help                  Print usage.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Position=0)]
        [array]
        $ArgumentList = $args
    )

    if (-not $Env:PSEdit) {
        # If path to code.cmd is not yet known, use the supporting function Assert-PSEdit to establish it
        Write-Verbose -Message '$Env:PSEdit is not yet defined. Invoking Assert-PSEdit.'
        Assert-PSEdit
    }

    if ($Env:PSEdit -NotLike "*powershell_ise.exe") {
        $ArgsArray = @("--user-data-dir $(Join-Path -Path $HOME -Childpath 'VSCode')",'--reuse-window')
    }

    if ($Args -or $ArgumentList) {
        # sanitize passed parameters ?
        Write-Verbose -Message 'Processing $args.'
        #$ArgumentList = $args
        foreach ($token in @($ArgumentList -split ',')) {
            Write-Debug -Message "Processing `$args token '$token'"
            # TODO Enhance Advanced function with parameter validation to match code.cmd / code.exe
            # Check for unescaped spaces in file path arguments
            if ($token.Contains(' ')) {
                if (Test-Path -Path $token) {
                    Write-Debug -Message "Wrapping  `$args token (path) $token with double quotes"
                    $token = """$token"""
                } else {
                    Write-Debug -Message "`$args token $token failed Test-Path, so NOT wrapping with double quotes"
                    $token = $token
                }
            } else {
                $token = $token
            }
            Write-Verbose -Message "Adding $token to `$ArgsArray"
            $ArgsArray += $token
        }
        Write-Verbose -Message "Results of processing `$args: $ArgsArray"
    }
    Write-Output -InputObject "Launching $Env:PSEdit $ArgsArray`n"
    Start-Process -NoNewWindow -FilePath $Env:PSEdit -ArgumentList $ArgsArray
    # & "${env:CommonProgramFiles(x86)}\Microsoft VS Code Insiders\bin\code-insiders.cmd" $ArgsArray
}

New-Alias -Name psedit -Value Open-PSEdit -Scope Global -Force

# Conditionally restore this New-Alias invocation, with a check for 'VS Code' in Env:PATH
# New-Alias -Name Code -Value Open-PSEdit -Scope Global -Force
