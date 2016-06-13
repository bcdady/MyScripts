# PowerShell $Profile
# Created by New-Profile function of ProfilePal module

Write-Output "`n`tLoading PowerShell `$Profile: CurrentUserAllHosts`n";

# Determine and set path/prompt location to [My ]Documents\WindowsPowerShell
$myWPS = $(join-Path -Path "$([Environment]::GetFolderPath('MyDocuments'))" -ChildPath 'WindowsPowerShell')
# Handle when special Environment variable MyDocuments is a mapped drive, it returns as the full UNC path.
if ("$([Environment]::GetFolderPath('MyDocuments'))".Substring(0,2) -match '\\') 
{
    $myWPS = $myWPS.Replace("$(Split-Path -Path "$([Environment]::GetFolderPath('MyDocuments'))" -Parent)"+'\',$(Get-PSDrive -PSProvider FileSystem | Where-Object -FilterScript {
                $PSItem.DisplayRoot -eq $(Split-Path -Path "$([Environment]::GetFolderPath('MyDocuments'))" -Parent) 
    }).Root)
}
Set-Location -Path $myWPS

# Load Sperry / Autopilot functions module;
Write-Output "`n # loading Sperry Module #"; Import-Module Sperry; # -Debug;
# Sperry requires PSLogger module as a dependency, so we can also call write-log and show-progress

write-output ' # loading ProfilePal Module #'; Import-Module -Name ProfilePal; # -Verbose;

# Preset Table Formats
# http://blogs.technet.com/b/heyscriptingguy/archive/2012/11/02/powertip-automatically-format-your-powershell-table.aspx
$PSDefaultParameterValues=@{'Format-Table:autosize'=$true;'Format-Table:wrap'=$true}

function Update-UAC {
    & UserAccountControlSettings.exe;
}
