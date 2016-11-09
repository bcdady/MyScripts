#Requires -Version 3.0
# -Module PSLogger
# PowerShell $Profile
# Originally created by New-Profile cmdlet in ProfilePal Module; modified for ps-core compatibility (use on Mac) by @bcdady 2016-09-27
# ~/.config/powershell/Microsoft.PowerShell_profile.ps1    

$Script:startingPath = $pwd
# capture starting path so we can go back after other things happen
<#$Global:defaultBanner = @'
Windows PowerShell
Copyright (C) 2016 Microsoft Corporation. All rights reserved.
'@

# -Optional- Specify custom font colors
# Uncomment the following if block to tweak the colors of your console; the 'if' statement is to make sure we leave the ISE host alone
<#if ($host.Name -eq 'ConsoleHost')
{
    $host.ui.rawui.backgroundcolor = 'gray'
    $host.ui.rawui.foregroundcolor = 'darkblue'
    # blue on gray work well in Console
    Clear-Host
    # clear-host refreshes the background of the console host to the new color scheme
    Start-Sleep -Seconds 1
    # wait a second for the clear command to refresh
    Write-Output -InputObject $defaultBanner
    # after clear-host, restore default PowerShell banner
}
#>

Write-Output -InputObject "`n`tLoading PowerShell `$Profile: CurrentUserCurrentHost`n"

 # or $host.Version.ToString()

# move/copy to AllUsersAllHosts
<# Get-Variable -Name Is*                                                                                

Name                           Value                                                                                  
----                           -----                                                                                  
IsCoreCLR                      True                                                                                   
IsLinux                        False                                                                                  
IsOSX                          True                                                                                   
IsWindows                      False  
#>

# Detect older versions of PowerShell and add in new automatic variables for more recent cross-platform compatibility
if ($Host.Version.Major -le 5) {
        $Global:IsWindows = $true
        $Global:PSEDition = 'Native'
}

if ($IsWindows) { $hostOS = 'Windows' } 
if ($IsLinux)   { $hostOS = 'Linux' } 
if ($IsOSX)     { $hostOS = 'OSX' }

Write-Output -InputObject " # $ShellId $($Host.version.tostring().substring(0,3)) $PSEdition on $hostOS #"

Write-Output -InputObject "Setting environment HostOS to $hostOS"
$env:HostOS = $hostOS

Write-Output -InputObject "`nCurrent PS execution policy is: "
Get-ExecutionPolicy -List | Format-Table -AutoSize

# Learn PowerShell today ...
# Thanks for this tip goes to: http://jdhitsolutions.com/blog/essential-powershell-resources/
Write-Output -InputObject ' # selecting (2) random PowerShell cmdlet help to review #'

if ($IsWindows)
{
Get-Command -Module Microsoft*, Cim*, PS*, ISE |
    Get-Random |
    Get-Help -ShowWindow

    Get-Random (Get-Help -Name about_*) |
    Get-Help -ShowWindow
}

Write-Output -InputObject ''
# Invoke-Expression (New-Object Net.WebClient).DownloadString('http://bit.ly/e0Mw9w')

<# check and conditionally update/fix PSModulePath
on Mac, default PSMODULEPATH (yes, it's case sensitive) is: $env:USERPROFILE/.local/share/powershell/Modules;;/usr/local/microsoft/powershell/Modules
#>

Write-Output -InputObject 'Check Modules Paths: $myPSmodPath'
if ($IsWindows)
{
    # Use local $HOME if GPO/UNC $HOME is not available
    if (-not (test-path -path $HOME)) {Set-Variable -Name HOME -Value $Env:USERPROFILE -Force}
    $splitChar = ';'
    $myPSmodPath = (Join-Path -Path $HOME -ChildPath 'Documents\WindowsPowerShell\Modules')
    if (-not (Test-Path -Path $myPSmodPath))
    {
        New-Item -Path (Join-Path -Path $HOME -ChildPath 'Documents\WindowsPowerShell') -ItemType Directory -Name 'Modules'
    }
#    if ("$env:USERPROFILE" -ne "$HOME")
#    {
#        $env:PSMODULEPATH  = $env:PSMODULEPATH  + ";$myPSmodPath"
#   }
}
else
{
    $splitChar = ':'
    $myPSmodPath = (Join-Path -Path $HOME -ChildPath '.local/share/powershell/Modules')
    # OR /usr/local/share/powershell/Modules
}

Write-Output -InputObject "Modules Path: $myPSmodPath"
Write-Output -InputObject "Scripts Path: $($myPSmodPath.Replace('Modules','Scripts'))"

if (-not ($myPSmodPath -in @($env:PSMODULEPATH -split $splitChar)))
{
    # Improve to only conditionally modify 
    # $env:PSMODULEPATH = @("$HOME\Documents\WindowsPowerShell\Modules"; "$pshome\Modules"; "${env:ProgramFiles(x86)}\WindowsPowerShell\Modules"; "$env:ProgramFiles\WindowsPowerShell\Modules") -join ';'
    Write-Output -InputObject "Adding Modules Path: $myPSmodPath to `$env:PSMODULEPATH"
    $env:PSMODULEPATH += ';' + $myPSmodPath
    $env:PSMODULEPATH
}

# try to update PS help files, if we have local admin role/rights
Write-Output -InputObject 'Checking if PS Help files are due to be updated' 
if (([security.principal.windowsprincipal] [security.principal.windowsidentity]::GetCurrent()).isinrole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
{
    if (-not ($Global:PSState))
    {
        Write-Warning -Message "Fatal Error loading PowerShell saved state info from custom object: $PSState"
    }
    # Check $PSHelpUpdatedDate, from previously saved state; should be loaded from json file into variable by Sperry     
    $PSHelpUpdatedDate = Get-Date -Date ($Global:PSState.HelpUpdatedDate -as [DateTime])
    Write-Output -InputObject "PS Help (Last) Updated Date: $PSHelpUpdatedDate"
    $NextUpdateDate = $PSHelpUpdatedDate.AddDays(10)
    Write-Debug -Message "PS Help Next Update Date: $NextUpdateDate"
    # Is today on or after $NextUpdateDate ?
    if ($NextUpdateDate -ge (Get-Date)) {
        # We DON'T need to Update Help right now
        $updateNow = $false
        Write-Debug -Message "We DON'T need to Update Help right now"
    }
    else
    {
        Write-Debug -Message "Iterate through current modules that have a HelpInfoUri defined, and attempt to update their help"
        # Iterate through current modules that have a HelpInfoUri defined, and attempt to update their help 
        Get-Module -ListAvailable | Where HelpInfoUri | sort -Property Name -Unique | foreach {"Update-Help -Module $($PSItem.Name)"; Update-Help -Module $($PSItem.Name)}

        Write-Debug -Message "Update `$PSHelpUpdatedDate to today"
        $PSHelpUpdatedDate = (Get-Date -DisplayHint Date -Format d)
        # Update custom object property, and write to settings state file 
        Write-Debug -Message "`$PSHelpUpdatedDate is $PSHelpUpdatedDate"
        $Global:PSState.HelpUpdatedDate = $PSHelpUpdatedDate
        Write-Debug -Message "`$Global:PSState is $Global:PSState"

        Set-Content -Path $PSProgramsDir\Microsoft.PowerShell_state.json -Value ($Global:PSState | ConvertTo-Json) -Confirm
    }
}
else
{
    Write-Log -Message "Skipping update-help, because we're either not on Windows, or do not have admin permissions" # `nConsider using get-help [term] -Online"
}

Write-Output -InputObject ''
# dot-source script file containing Get-NetSite function
. .\Scripts\NetSiteName.ps1
# Write-Output -InputObject 'Network connection info:'
$NetInfo = Get-NetSite
Write-Output -InputObject "Connected at Site: $($NetInfo.SiteName) (Address: $($NetInfo.IPAddress))" # | Select-Object -First 1))"

Write-Output -InputObject 'Importing function Out-Copy'
# dot-source Out-Copy function script
. .\Scripts\out-copy.ps1

Write-Output -InputObject 'Importing function Out-Highlight'
# dot-source Out-Highlight function script
. .\Out-Highlight.ps1

Write-Output -InputObject ''
# Prompt to backup log files
Write-Output -InputObject 'Archive PowerShell logs'
Backup-Logs

Write-Output -InputObject ''
Write-Output -InputObject 'Updating this window title'
Set-WindowTitle

Write-Output -InputObject 'Declaring function Find-UpdatedDSCResource'
function Find-UpdatedDSCResource {

$MyDSCmodules = Get-Module -ListAvailable | Where-Object {'DSC' -in $_.Tags} | Select-Object -Property Name,Version

    Write-Output -InputObject 'Checking PowerShellGallery for new or updated DSC Resources'
    Write-Output -InputObject 'Find-Package -ProviderName PowerShellGet -Tag DscResource | Format-List -Property Name,Status,Summary'
    #Find-Package -ProviderName PowerShellGet -Tag DscResource | Format-List -Property Name,Status,Summary | Out-Host -Paging
    $DSCResources = Find-Module -Tag DscResource -Repository PSGallery
    foreach ($pkg in $DSCResources)
    {
        if ($pkg -in $MyDSCmodules.Name) {
            if ($pkg.Version -gt $MyDSCmodules.$($pkg.Name).Version) {
                "Update to $pkg.Name is available"
            }
        }
        else
        {
            "Reviewing new DSC Resource module packages available from PowerShellGallery"
            $pkg | Format-List -Property Name,Description,Dependencies,PublishedDate;
            if ([string](Read-Host -Prompt 'Would you like to install this resource module? [Y/N]') -eq 'y'){
                Write-Output -InputObject "Installing and importing $($pkg.Name) from PowerShellGallery"
                $pkg | Install-Module -Scope CurrentUser -Verbose
                Import-Module -Name $pkg.Name -PassThru -Verbose
            }
            else
            {
                Write-Output -InputObject ' moving on ...'
            }
        Write-Output -InputObject ' # # # Next Module # # #'
        }
    }
}

# Find-UpdatedDSCResources

Write-Output -InputObject 'Declaring function Get-PSGalleryModule'
function Get-PSGalleryModule
{
    Find-Module -Repository psgallery | Sort-Object -Descending -Property PublishedDate | Select-Object -First 30 | Format-List Name, PublishedDate, Description, Version | Out-Host -Paging
}

# commented out in favor of starting VS Code Insiders via Sperry / Set-ProcessState function
# re-open Visual Studio code PowerShell extension examples
# & code $env:USERPROFILE\.vscode\extensions\ms-vscode.PowerShell\examples

Write-Output -InputObject 'Declaring function Open-Code'
function Open-Code
{
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

    Write-Debug -Message 'Start Code Insiders'
    if ($ArgumentList)
    {
        # sanitize passed parameters
        $ArgsArray = @()
        foreach ($filePath in @($ArgumentList -split ','))
        {
            if (test-path -Path $filePath -PathType Leaf)
            {
                $ArgsArray += $filePath
            }
        }
    }
    Write-Debug -Message "& code-insiders.cmd $ArgsArray"
    & 'C:\Program Files (x86)\Microsoft VS Code Insiders\bin\code-insiders.cmd' $ArgsArray
}

Write-Output -InputObject 'Declaring aliases and XenApp shortcut functions'
# Setup PS aliases for launching common apps, including XenApp
New-Alias -Name psedit -Value Open-Code -ErrorAction Ignore

New-Alias -Name rdp -Value Start-RemoteDesktop -ErrorAction Ignore

# New-Alias -Name pa_start -Value $env:SystemDrive\SWTOOLS\Start.exe -Description 'start PortableApps' -Option Constant
# New-Alias -Name pa_firefox -Value $env:SystemDrive\SWTOOLS\PortableApps\FirefoxPortable\FirefoxPortable.exe -Description 'Start PortableApp : Firefox' -Option Constant
# New-Alias -Name pa_chrome -Value $env:SystemDrive\SWTOOLS\PortableApps\GoogleChromePortable\GoogleChromePortable.exe -Description 'Start PortableApp : Chrome browser' -Option Constant
# New-Alias -Name pa_edit -Value C:\SWTOOLS\PortableApps\SublimeText3Portable\App\SublimeText3Portable\sublime_text.exe -Description 'Start PortableApp : SublimeText editor' -Option Constant

New-Alias -Name rename -Value Rename-Item

function xa_assyst
{
    write-output -inputobject 'Start-XenApp -Qlaunch assyst'
    Start-XenApp -Qlaunch assyst
}

function xa_cmd
{
    write-output -inputobject 'Start-XenApp -Qlaunch cmd'
    Start-XenApp -Qlaunch cmd
}
function xa_excel
{
    write-output -inputobject 'Start-XenApp -Qlaunch Excel'
    Start-XenApp -Qlaunch excel
}
New-Alias -Name xa_xl -Value xa_excel

function xa_hdrive
{
    write-output -inputobject 'Start-XenApp -Qlaunch h_drive'
    Start-XenApp -Qlaunch h_drive
}
New-Alias -Name xa_explorer -Value xa_hdrive

New-Alias -Name xa_h -Value xa_hdrive

function xa_IE
{
    write-output -inputobject 'Start-XenApp -Qlaunch IE'
    Start-XenApp -Qlaunch IE
}
function xa_itsc
{
    write-output -inputobject 'Start-XenApp -Qlaunch itsc'
    Start-XenApp -Qlaunch itsc
}
function xa_firefox
{
    write-output -inputobject 'Start-XenApp -Qlaunch Firefox'
    Start-XenApp -Qlaunch FireFox
}
function xa_mstsc
{
    write-output -inputobject 'Start-XenApp -Qlaunch mstsc'
    Start-XenApp -Qlaunch mstsc
}
New-Alias -Name xa_rdp -Value xa_mstsc

function xa_onenote
{
    write-output -inputobject 'Start-XenApp -Qlaunch onenote'
    Start-XenApp -Qlaunch onenote
}
function xa_outlook
{
    write-output -inputobject 'Start-XenApp -Qlaunch outlook'
    Start-XenApp -Qlaunch outlook
}
function xa_powerpoint
{
    write-output -inputobject 'Start-XenApp -Qlaunch powerpoint'
    Start-XenApp -Qlaunch powerpoint
}
New-Alias -Name xa_ppt -Value xa_powerpoint

function xa_sdrive
{
    write-output -inputobject 'Start-XenApp -Qlaunch s_drive'
    Start-XenApp -Qlaunch s_drive
}
New-Alias -Name xa_s -Value xa_sdrive

function xa_skype
{
    write-output -inputobject 'Start-XenApp -Qlaunch ''Skype for Business'''
    Start-XenApp -Qlaunch 'Skype for Business'
}
New-Alias -Name xa_s4b -Value xa_skype

function xa_synergy
{
    write-output -inputobject 'Start-XenApp -Qlaunch synergy'
    Start-XenApp -Qlaunch synergy
}
function xa_visio
{
    write-output -inputobject 'Start-XenApp -Qlaunch visio'
    Start-XenApp -Qlaunch visio
}
function xa_word
{
    write-output -inputobject 'Start-XenApp -Qlaunch word'
    Start-XenApp -Qlaunch word
}
function xa_reconnect
{
    write-output -inputobject 'Start-XenApp -Reconnect'
    Start-XenApp -Reconnect
}

function logon-work
{
    write-output -inputobject 'Set-Workplace -zone Office'
    Set-Workplace -zone Office
}

New-Alias -Name start-work -Value logon-work

function logoff-work
{
    write-output -inputobject 'Set-Workplace -zone Remote'
    Set-Workplace -zone Remote
}

New-Alias -Name stop-work -Value logoff-work
