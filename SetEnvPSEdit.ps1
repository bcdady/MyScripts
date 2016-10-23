#!/usr/local/bin/powershell

write-output -InputObject "Declaring Function Set-PSEdit" 
Function Set-PSEdit
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$true,
                   ValueFromPipelineByPropertyName=$true,
                   Position=0)]
        $Path
        
    )

    # Detect PSISE on Windows, and/or VS Code on OSX or Linux
    if ($IsWindows)
    {
        # fill this in with code from Windows host
        # Detect code in Path, otherwise fallback to ISE
        $env:PSEdit = $vscode
    } 
    else
    {
        # Ask host os for the path to Visual Studio Code (via which binary/exe)
        $vscode = Resolve-Path -Path (which code)
        if ($?)
        {
            $env:PSEdit = $vscode
        }
    }
}

write-output -InputObject "Declaring Function Get-PSEdit"
Function Get-PSEdit
{
    Get-ChildItem Env:PSEdit -ErrorAction SilentlyContinue
}

