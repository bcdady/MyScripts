#Requires -Version 3.0 -Module PSLogger
# PowerShell $Profile
# Created by New-Profile cmdlet in ProfilePal Module

$Script:startingPath = $pwd
# capture starting path so we can go back after other things happen
$Global:defaultBanner = @'
Windows PowerShell
Copyright (C) 2013 Microsoft Corporation. All rights reserved.
'@

# -Optional- Specify custom font colors
# Uncomment the following if block to tweak the colors of your console; the 'if' statement is to make sure we leave the ISE host alone
if ($host.Name -eq 'ConsoleHost')
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

Write-Log -Message "`n`tLoading PowerShell `$Profile: CurrentUserCurrentHost`n"-Function $env:USERNAME -Verbose

Write-Log -Message "`nCurrent PS execution policy is: $env:PSExecutionPolicyPreference" -Function $env:USERNAME
Write-Output -InputObject "`nCurrent PS execution policy is: "
Get-ExecutionPolicy -List | Format-Table -AutoSize

# Learn PowerShell today ...
# Thanks for this tip goes to: http://jdhitsolutions.com/blog/essential-powershell-resources/
Write-Output -InputObject ' # selecting (2) random PowerShell cmdlet help to review #'

Get-Command -Module Microsoft*, Cim*, PS*, ISE |
    Get-Random |
    Get-Help -ShowWindow

Get-Random -InputObject (Get-Help -Name about*) |
    Get-Help -ShowWindow

# Invoke-Expression (New-Object Net.WebClient).DownloadString('http://bit.ly/e0Mw9w')

<# check and conditionally update/fix PSModulePath
$env:PSModulePath = @("$home\Documents\WindowsPowerShell\Modules"; "$pshome\Modules"; "${env:ProgramFiles(x86)}\WindowsPowerShell\Modules"; "$env:ProgramFiles\WindowsPowerShell\Modules") -join ';'

if ("$env:USERPROFILE" -ne "$home") {
    $Env:PSModulePath = $Env:PSModulePath + ";$env:USERPROFILE\Documents\WindowsPowerShell\Modules"
}
#>

# dot-source script file containing Get-NetSite function
. .\Scripts\NetSiteName.ps1

# dot-source Out-Copy function script
. .\Scripts\out-copy.ps1

# dot-source Out-Highligt function script
. .\Out-Highlight.ps1

# Write-Output -InputObject 'Network connection info:'
Write-Log -Message "Connected at $((Get-NetSite).SiteName) ($((Get-NetSite).IPAddress | Select-Object -First 1))" -Function $env:USERNAME -Verbose

# Prompt to backup log files
Write-Log -Message 'Archive PowerShell logs' -Function $env:USERNAME
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

# re-open Visual Studio code PowerShell extension examples
& code $env:USERPROFILE\.vscode\extensions\ms-vscode.PowerShell\examples

# Setup PS aliases for launching common apps, including XenApp
New-Alias -Name rdp -Value Start-RemoteDesktop -ErrorAction Ignore

New-Alias -Name pa_start -Value $env:SystemDrive\SWTOOLS\Start.exe -Description 'start PortableApps' -Option Constant

New-Alias -Name pa_firefox -Value $env:SystemDrive\SWTOOLS\PortableApps\FirefoxPortable\FirefoxPortable.exe -Description 'Start PortableApp : Firefox' -Option Constant

New-Alias -Name pa_chrome -Value $env:SystemDrive\SWTOOLS\PortableApps\GoogleChromePortable\GoogleChromePortable.exe -Description 'Start PortableApp : Chrome browser' -Option Constant

New-Alias -Name pa_edit -Value C:\SWTOOLS\PortableApps\SublimeText3Portable\App\SublimeText3Portable\sublime_text.exe -Description 'Start PortableApp : SublimeText editor' -Option Constant

New-Alias -Name rename -Value Rename-Item

function xa_assyst
{
    Start-XenApp -Qlaunch assyst
}
function xa_cmd
{
    Start-XenApp -Qlaunch cmd
}
function xa_excel
{
    Start-XenApp -Qlaunch excel
}
New-Alias -Name xa_xl -Value xa_excel
function xa_hdrive
{
    Start-XenApp -Qlaunch h_drive
}
New-Alias -Name xa_explorer -Value xa_hdrive

New-Alias -Name xa_h -Value xa_hdrive
function xa_IE
{
    Start-XenApp -Qlaunch IE
}
function xa_itsc
{
    Start-XenApp -Qlaunch itsc
}
function xa_firefox
{
    Start-XenApp -Qlaunch FireFox
}
function xa_mstsc
{
    Start-XenApp -Qlaunch mstsc
}
New-Alias -Name xa_rdp -Value xa_mstsc
function xa_onenote
{
    Start-XenApp -Qlaunch onenote
}
function xa_outlook
{
    Start-XenApp -Qlaunch outlook
}
function xa_powerpoint
{
    Start-XenApp -Qlaunch powerpoint
}
New-Alias -Name xa_ppt -Value xa_powerpoint
function xa_sdrive
{
    Start-XenApp -Qlaunch s_drive
}
New-Alias -Name xa_s -Value xa_sdrive
function xa_skype
{
    Start-XenApp -Qlaunch 'Skype for Business'
}
New-Alias -Name xa_s4b -Value xa_skype
function xa_synergy
{
    Start-XenApp -Qlaunch synergy
}
function xa_visio
{
    Start-XenApp -Qlaunch visio
}
function xa_word
{
    Start-XenApp -Qlaunch word
}
function xa_reconnect
{
    Start-XenApp -Reconnect
}

function logon-work
{
    Set-Workplace -zone Office
}

New-Alias -Name start-work -Value logon-work

function logoff-work
{
    Set-Workplace -zone Remote
}

New-Alias -Name stop-work -Value logoff-work
