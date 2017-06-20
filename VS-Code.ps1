#!/usr/local/bin/powershell
#Requires -Version 2

# & code $env:USERPROFILE\.vscode\extensions\ms-vscode.PowerShell\examples

Write-Verbose -Message 'Declaring function Open-Code'
function Open-Code
{
[CmdletBinding(SupportsShouldProcess)]
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
    param (
        [Parameter(Position=0)]
        [array]
        $ArgumentList
    )

    Write-Verbose -Message 'Start Code Insiders'
    Write-Verbose -Message 'Args'
    $args

    $ArgsArray = @('-r')

    if ($ArgumentList)
    {
        # sanitize passed parameters ?
        foreach ($token in @($ArgumentList -split ','))
        {
            # TODO add hygiene check for supported non-path arguments
#            if (test-path -Path $token -PathType Leaf)
#            {
                $ArgsArray += $token
#            }
        }
    }
    Write-Debug -Message "& code-insiders.cmd $ArgsArray"
    Start-Process -NoNewWindow -FilePath "${env:ProgramFiles(x86)}\Microsoft VS Code Insiders\bin\code-insiders.cmd" -ArgumentList $ArgsArray
#    & "${env:CommonProgramFiles(x86)}\Microsoft VS Code Insiders\bin\code-insiders.cmd" $ArgsArray
}

# Setup PS aliases for launching common apps, including XenApp
New-Alias -Name psedit -Value Open-Code -ErrorAction Ignore
