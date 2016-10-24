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

# Invoke-Expression (New-Object Net.WebClient).DownloadString('http://bit.ly/e0Mw9w')

<# check and conditionally update/fix PSModulePath
on Mac, default PSMODULEPATH (yes, it's case sensitive) is: $env:USERPROFILE/.local/share/powershell/Modules;;/usr/local/microsoft/powershell/Modules
#>

if ($IsWindows)
{
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

Write-Output -InputObject "PowerShell Modules Path: $myPSmodPath"
Write-Output -InputObject "PowerShell Scripts Path: $($myPSmodPath.Replace('Modules','Scripts'))"

if (-not ($myPSmodPath -in @($env:PSMODULEPATH -split $splitChar)))
{
    # Improve to only conditionally modify 
    # $env:PSMODULEPATH = @("$HOME\Documents\WindowsPowerShell\Modules"; "$pshome\Modules"; "${env:ProgramFiles(x86)}\WindowsPowerShell\Modules"; "$env:ProgramFiles\WindowsPowerShell\Modules") -join ';'
}

# dot-source script file containing Get-NetSite function
. .\Scripts\NetSiteName.ps1

<# -suspending until PS v4
# dot-source Out-Copy function script
. .\Scripts\out-copy.ps1

# dot-source Out-Highligt function script
. .\Out-Highlight.ps1
#>

# Write-Output -InputObject 'Network connection info:'
Write-Output -InputObject "Connected at $((Get-NetSite).SiteName) ($((Get-NetSite).IPAddress | Select-Object -First 1))"

# Prompt to backup log files
Write-Output -InputObject 'Archive PowerShell logs'
Backup-Logs

Set-WindowTitle

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

function Get-PSGalleryModule
{
    Find-Module -Repository psgallery | Sort-Object -Descending -Property PublishedDate | Select-Object -First 30 | Format-List Name, PublishedDate, Description, Version | Out-Host -Paging
}

# commented out in favor of starting VS Code Insiders via Sperry / Set-ProcessState function
# re-open Visual Studio code PowerShell extension examples
# & code $env:USERPROFILE\.vscode\extensions\ms-vscode.PowerShell\examples

# Setup PS aliases for launching common apps, including XenApp
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
