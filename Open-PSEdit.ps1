#!/usr/local/bin/powershell
#Requires -Version 2
[CmdletBinding()]
Param()
#Set-StrictMode -Version latest

# Ensure this script is dot-sourced, to get access to it''s contained functions

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
  $Global:PSEdition = 'Windows'
}

# dot-source script file containing Add-PATH and related helper functions
#$RelativePath = Split-Path -Path (Resolve-Path -Path $MyScriptInfo.CommandPath) -Parent
Write-Verbose -Message "Initializing .\Edit-Path.ps1"
. $(Join-Path -Path (Split-Path -Path (Resolve-Path -Path $MyScriptInfo.CommandPath) -Parent) -Childpath 'Edit-Path.ps1')

# Declare path where the functions below should look for git.exe
# If/when needed, this path will be added to $Env:Path as a dependency of VS Code and some extensions
$GitPath = 'R:\IT\Microsoft Tools\VSCode\GitPortable\cmd'

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
        $Path = '$HOME\vscode\app\bin\code.cmd'
    )

    if ($Env:PSEdit) {
        if (Test-Path -Path $Env:PSEdit) {
            Write-Verbose -Message "Preparing to update / override `$Env:PSEdit $Env:PSEdit with $Path"
        } else {
            Write-Verbose -Message "`$Env:PSEdit is currently pointed at invalid Path: $Env:PSEdit"
        }
    }

    Write-Verbose -Message 'Seeking an available editor: either VS Code or ISE'
    $vscode = $null
    if ($IsWindows) {
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
    } else {
        Write-Verbose -Message 'Detected NOT Windows OS. Checking for result from ''which code'''
        # Ask host os for the path to Visual Studio Code (via which binary/exe)
        $ErrorActionPreference = 'SilentlyContinue'
        $vscode = Resolve-Path -Path (which code) -ErrorAction SilentlyContinue
        $ErrorActionPreference = 'Continue'
    }

    if ($null -ne $vscode) {
        Write-Verbose -Message "Setting `$Env:PSEdit to `$vscode: $vscode"
        $Env:PSEdit = $vscode
    # Write-Debug -Message 'Failed to locate an available instance of VS code'
    } elseif (Test-Path -Path $Path -PathType Leaf -ErrorAction SilentlyContinue) {
            $Path = Resolve-Path -Path $Path
            Write-Verbose -Message "Setting `$Env:PSEdit to Path (Parameter): $Path"
            $Env:PSEdit = $Path
            if ($IsWindows -and ($Path -like "*\\code\.")) {
                # Check and update $Env:PATH to include path to code; some code extensions look for code in the PATH
                Write-Verbose -Message "Adding $(Split-Path -Path $Env:PSEdit -Parent -Resolve) to `$Env:PATH"
                # Send output from Add-EnvPath to Null, so we don't have to read $Env:Path in the console
                # No need for pre-processing, as Add-EnvPath function handles attempts to add duplicate path statements
                Add-EnvPath (Split-Path -Path $Env:PSEdit -Parent -Resolve) | Out-Null
                # Check and conditionally update File Type Associations, to make it easier to open supported file types in VS Code, from Windows Explorer
    <#          if (Test-FileTypeAssociation) {
                    Write-Verbose -Message 'Expected file types are associated with VS code'
                } else {
                    Write-Verbose -Message 'Associating specified file types with VS code'
                    Add-FileType
                }
    #>
            }
    } elseif ($PSISE) {
        Write-Verbose -Message "Setting `$Env:PSEdit to $PSISE"
        $Env:PSEdit = $PSISE
    }

    return $Env:PSEdit
}

Write-Verbose -Message 'Declaring Function Test-FileTypeAssociation'
Function Test-FileTypeAssociation {
    [CmdletBinding()]
    Param (
        [Parameter(Position=0)]
        [string]$ProgID = 'vscode'
        ,
        [Parameter(Position=1)]
        [string]$Description = 'code file'
    )
    $ErrorActionPreference = 'SilentlyContinue'
    $Answer = (Get-ItemProperty -Path "HKCU:\Software\Classes\$ProgID" -Name '(Default)' -ErrorAction SilentlyContinue).'(Default)'
    Write-Verbose "ProgID $ProgID is associated as '$Answer'"
    $ErrorActionPreference = 'Continue'
    if ($Answer -eq $Description) {
        return $true
    } else {
        return $false
    }
}

Write-Verbose -Message 'Declaring Function Add-FileTypeAssociation'
Function Add-FileTypeAssociation {
    [CmdletBinding()]
    Param (
        [Parameter(Position=0)]
        [string]$ProgID = 'vscode'
        ,
        [Parameter(Position=1)]
        [ValidateScript({Test-Path -Path (Resolve-Path -Path $PSItem)})]
        [string]$CommandPath = '$HOME\vscode\app\code.exe'

    )
    # Programmatically update the Windows "Default Program" for file types / extensions supported by VS Code

    <#
        Method 1: Old school
        https://technet.microsoft.com/en-us/library/ff687021.aspx
        https://superuser.com/questions/406985/programatically-associate-file-extensions-with-application-on-windows
        cmd /c assoc .ps1

        Method 2: Registry 'hack'
        Reminder: "HKEY_CLASSES_ROOT" is an alias to HKLM:\SOFTWARE\Classes

        HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Explorer\FileExts
        See also:
        Programmatic Identifiers
        https://msdn.microsoft.com/en-us/library/windows/desktop/cc144152(v=vs.85).aspx
    #>

    $CodeFileTypes = @('.bash','.bashrc','.bash_login','.bash_logout','.bash_profile','.bat','.cmd','.coffee','.config','.css','.gitattributes','.gitconfig','.gitignore','.go','.htm','.html','.ini','.js','.json','.lua','.kix','.markdown','.md','.mdoc','.mdown','.mdtext','.mdtxt','.mdwn','.mkd','.mkdn','.pl','.pl6','.pm','.pm6','.profile','.properties','.ps1','.psd1','.psgi','.psm1','.py','.sh','.sql','.t','.tex','.ts','.txt','.vb','.vbs','.xaml','.xml','.yaml','.yml','.zsh')
    #$ProgID = 'vscode'

    # Create a new "Edit" verb key under the current user's Classes hive for the ProgID association
    # For PS1 / Microsoft.PowerShellScript.1, Edit is typically ISE, and 'Open' invokes Notepad
    New-Item -Path "HKCU:\Software\Classes\$ProgID" -Force
    Write-Verbose "Set-ItemProperty -Path ""HKCU:\Software\Classes\$ProgID"" -Name '(Default)' -Value 'code file'"
    Set-ItemProperty -Path "HKCU:\Software\Classes\$ProgID" -Name '(Default)' -Value 'code file'
    Write-Verbose "New-Item -Path HKCU:\SOFTWARE\Classes\$ProgID\shell\Edit with VS Code\command :: ""$CommandPath"" ""%1"""
    New-Item -Path "HKCU:\SOFTWARE\Classes\$ProgID\shell\Edit with VS Code\command" -Force -ErrorAction SilentlyContinue | out-null
    New-ItemProperty -Path "HKCU:\SOFTWARE\Classes\$ProgID\shell\Edit with VS Code\command" -Name '(Default)' -PropertyType String -Value """$CommandPath"" ""%1"""

    # Build an associative array / hash table of current FileExt / File Types and their ProgID Association(s) File Type Association (a.k.a. FTA)
    $CodeFileTypes | ForEach-Object -Process {
        Write-Verbose "Updating FileType Association -- HKCU:\SOFTWARE\Classes\$PSItem :: $ProgID"
        New-Item -Path "HKCU:\SOFTWARE\Classes\$PSItem" -Force -ErrorAction SilentlyContinue | out-null
        New-ItemProperty -Path "HKCU:\SOFTWARE\Classes\$PSItem" -Name '(Default)' -PropertyType String -Value "$ProgID" -ErrorAction SilentlyContinue | out-null
        #Write-Debug -Message "FTA for $PSItem is $ProgID"
        #$FTA.Add($PSItem,$ProgID)
    }

    Write-Verbose ' > (line break)'
    Write-Verbose ' > (line break)'
    Write-Verbose ' > (line break)'
    Write-Warning -Message " !`t!`t!`n`t> > > `n`t> > > Restarting Windows Explorer to refresh your file type associations.`n`t> > > "
    '10 ...'
    Start-Sleep -Seconds 1
    '9 ...'
    Start-Sleep -Seconds 1
    '8 ...'
    Start-Sleep -Seconds 1
    '7 ...'
    Start-Sleep -Seconds 1
    '6 ...'
    Start-Sleep -Seconds 1
    '5 ...'
    Start-Sleep -Seconds 1
    '4 ...'
    Start-Sleep -Seconds 1
    '3 ...'
    Start-Sleep -Seconds 1
    '2 ...'
    Start-Sleep -Seconds 1
    '1 ...'
    Start-Sleep -Seconds 1
    Get-Process -Name explorer* | Stop-Process
    #Start-Sleep -Seconds 1
    "Opening Explorer to $HOME"
    Start-Sleep -Seconds 1
    & explorer.exe $HOME
}

Write-Verbose -Message 'Declaring Function Initialize-Git'
Function Initialize-Git {
    [CmdletBinding()]
    param (
	    [parameter(Mandatory, 
	        ValueFromPipeline,
	        Position = 0)]
        [Alias('Folder')]
	    [String]$Path
	)

    if (($null -ne $Path) -and (Test-Path -Path $Path -PathType Container)) {
        $gitdir = Resolve-Path -Path $Path
    } else {
        Write-Warning -Message "Encountered error validating folder path $Path"
    }

    if (Get-Variable -Name gitdir -ErrorAction Ignore) {
        # Check and update $Env:PATH to include path to code; some code extensions look for code in the PATH
        Write-Verbose -Message "Adding (git) $gitdir to `$Env:PATH"
        # Send output from Add-EnvPath to Null, so we don't have to read $Env:Path in the console
        Add-EnvPath -Path $gitdir # | Out-Null
        $Env:GIT_DIR = $gitdir

        Write-Warning -Message "Add-EnvPath -Path $gitdir may not have succeeded."
        Write-Host -Message "`$Env:PATH += ;$gitdir"
        $Env:PATH += ";$gitdir"

        if ($Env:PATH -split ';' -contains $gitdir) {
            return $True # $gitdir
        } else {
            Write-Warning -Message "Git directory $Path was not properly added to the PATH"
            return $false
        }
    } else {
        Write-Host -Message '-Path to GIT_DIR either not specified or Path not valid'
    }
}
New-Alias -Name Init-Git -Value Initialize-Git -Scope Global -Force

Write-Verbose -Message 'Declaring Function Open-PSEdit'
function Open-PSEdit {
    <#
        Visual Studio Code
        Usage: code.exe [options] [paths...]

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

        Potential enhancements, as examples of code.exe / code-insiders.exe parameters
        --install-extension guosong.vscode-util --install-extension ms-vscode.PowerShell --install-extension Shan.code-settings-sync --install-extension wmaurer.change-case --install-extension DavidAnson.vscode-markdownlint
        --install-extension LaurentTreguier.vscode-simple-icons --install-extension seanmcbreen.Spell --install-extension mohsen1.prettify-json --install-extension ms-vscode.Theme-MarkdownKit 
    #>
    [CmdletBinding()]
    param (
        [Parameter(Position=0)]
        [array]
        $ArgumentList = $args
    )
    
    if (-not [bool]($Env:PSEdit)) {
        # If path to code.cmd is not yet known, use the supporting function Assert-PSEdit to establish it
        Write-Verbose -Message '$Env:PSEdit is not yet defined. Invoking Assert-PSEdit.'
        Assert-PSEdit
    }

    $ArgsArray = New-Object System.Collections.ArrayList

    if ($Env:PSEdit -Like "*\code*") {
        Write-Verbose -Message '$Env:PSEdit -Like "*code*"; adding VS Code arguments'
        # Define 'default' Options, to pass to code
        $ArgsArray.Add('--skip-getting-started')
        $ArgsArray.Add("--user-data-dir $(Join-Path -Path $HOME -Childpath 'vscode')")
        $ArgsArray.Add("--extensions-dir $(Join-Path -Path $HOME -Childpath 'vscode\extensions')")
        # also add --reuse-window parameter, unless --new-window or it's alias -n were set in @args
        if (($ArgumentList -notcontains '--new-window') -and ($ArgumentList -notcontains '-n')) {
            $ArgsArray.Add('--reuse-window')
        }
    <#  if (-not (Test-FileTypeAssociation)) {
            Add-FileTypeAssociation -ProgID 'vscode' -CommandPath $Env:PSEdit
        } #>
    }

    if ($Env:PSEdit -Like "*Microsoft VS Code*") {
        # If Code appears to be installed, as signalled by \Microsoft VS Code\ in it's path, then let it use default user-data-dir and extensions-dir
        $ArgsArray.Remove("--user-data-dir $(Join-Path -Path $HOME -Childpath 'vscode')")
        $ArgsArray.Remove("--extensions-dir $(Join-Path -Path $HOME -Childpath 'vscode\extensions')")
    }

    # While we're at it, double-check git is available via PATH, for use from within VS Code
    # See ..\GitPortable\README.portable.md
    # set gitdir=c:\portablegit
    # set path=%gitdir%\cmd;%path%
    # usage: git [--version] [--help] [-C <path>] [-c name=value]
    #         [--exec-path[=<path>]] [--html-path] [--man-path] [--info-path]
    #         [-p | --paginate | --no-pager] [--no-replace-objects] [--bare]
    #         [--git-dir=<path>] [--work-tree=<path>] [--namespace=<name>]
    #         <command> [<args>]
    if ($Env:PATH -notlike "*GitPortable\cmd*") {

        if (Test-Path -Path $GitPath) {
            Write-Verbose -Message "Initialize-Git -Path '$GitPath'"
            Initialize-Git -Path "$GitPath"
            # Derive .gitconfig path, then 'fix' the delimiter (swap from \ to /)
            $GitConfigPath = $((Join-Path -Path $HOME -ChildPath 'vscode\.gitconfig') -replace '\\','/')
            Write-Verbose -Message "Setting `$Env:GIT_CONFIG to $GitConfigPath"
            $Env:GIT_CONFIG = $GitConfigPath
            Write-Verbose -Message 'Setting $Env:GIT_CONFIG_NOSYSTEM = 1'
            $Env:GIT_CONFIG_NOSYSTEM = '1'
            Write-Verbose -Message '& git config credential.helper wincred'
            git config credential.helper wincred

            Write-Verbose -Message '& git --version'
            git --version
            if (!$?) {
                Write-Warning -Message "git --version returned an error, likely because git was not found in PATH. Suggest manually modifying PATH to support git before re-opening VS Code"
            } else {
                Write-Verbose -Message "To review your git configuration(s), run 'git config --list --show-origin --path'"
            }
        } else {
            Write-Verbose -Message "Failed to validate `$GitPath: $GitPath"
        }
    }

    if ($Args -or $ArgumentList) {
        # sanitize passed parameters ?
        Write-Verbose -Message 'Processing $args.'
        foreach ($token in $ArgumentList) {
            Write-Debug -Message "Processing `$args token '$token'"
            # TODO Enhance Advanced function with parameter validation to match code.cmd / code.exe
            # Check for unescaped spaces in file path arguments
            if ($token -notlike ' ') {
                Write-Verbose -Message "Check `$token for spaces"
                if (Test-Path -Path $token) {
                    Write-Debug -Message "Wrapping  `$args token (path) $token with double quotes"
                    $token = """$token"""
                } else {
                    Write-Debug -Message "`$args token $token failed Test-Path, so NOT wrapping with double quotes"
                    $token = $token
                }
            # } else {
            #     $token = $token
            }
            Write-Verbose -Message "Adding $token to `$ArgsArray"
            $ArgsArray.Add($token)
        }
        Write-Verbose -Message "Results of processing `$args: $ArgsArray"
    }
    Write-Output -InputObject "Launching $Env:PSEdit $ArgsArray`n"
    if ($ArgsArray) {
        # Pass non-null $ArgsArray to -ArgumentList
        Start-Process -NoNewWindow -FilePath $Env:PSEdit -ArgumentList $ArgsArray
    } else {
        # Skip -ArgumentList
        Start-Process -NoNewWindow -FilePath $Env:PSEdit
    }
}

New-Alias -Name psedit -Value Open-PSEdit -Scope Global -Force

# Conditionally restore this New-Alias invocation, with a check for 'VS Code' in Env:PATH
New-Alias -Name Code -Value Open-PSEdit -Scope Global -Force
