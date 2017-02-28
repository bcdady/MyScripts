<#
.SYNOPSIS
    Microsoft.PowerShellISE_profile.ps1 - PowerShell ISE profile
.DESCRIPTION
    Microsoft.PowerShellISE_profile - Customizes the PowerShell ISE editor experience
.NOTES
    File Name   : Microsoft.PowerShellISE_profile.ps1
    Author      : Bryan Dady
.LINK
    http://www.zerrouki.com/powershell-profile-example/
#>
<# 

 # NOTE Console and ISE will have distinct paths to these variables
 e.g. $Home\[My ]Documents\Profile.ps1
 vs   $Home\[My ]Documents\WindowsPowerShell\Microsoft.PowerShellISE_profile.ps1

See also about_Profiles

#>

Write-Output "`n`tLoading PowerShell `$Profile: CurrentUserCurrentHost_ISE`n"; # $PSCommandPath`n";

#Script Browser Begin
#Version: 1.3.2
Add-Type -Path 'C:\Program Files (x86)\Microsoft Corporation\Microsoft Script Browser\System.Windows.Interactivity.dll'
Add-Type -Path 'C:\Program Files (x86)\Microsoft Corporation\Microsoft Script Browser\ScriptBrowser.dll'
Add-Type -Path 'C:\Program Files (x86)\Microsoft Corporation\Microsoft Script Browser\BestPractices.dll'
$scriptBrowser = $psISE.CurrentPowerShellTab.VerticalAddOnTools.Add('Script Browser', [ScriptExplorer.Views.MainView], $true)
$scriptAnalyzer = $psISE.CurrentPowerShellTab.VerticalAddOnTools.Add('Script Analyzer', [BestPractices.Views.BestPracticesView], $true)
$psISE.CurrentPowerShellTab.VisibleVerticalAddOnTools.SelectedAddOnTool = $scriptBrowser
#Script Browser End

# by default, PS scans through $env:PSModulePath, so we don't need to check specific paths; instead use try / catch block

# ISEScriptingGeek
write-output ' # loading ISEScriptingGeek # '; import-module ISEScriptingGeek;
# PSharp
write-output ' # loading psharp # '; import-module psharp;
# ISEHg
#write-output ' # loading ISEHg # '; import-module ISEHg;
# ISERegex
write-output ' # loading ISERegex # '; Start-ISERegex;

# ISESteroids
if (![bool](Get-ChildItem "$env:APPDATA\ISESteroids\License" -Name ISESteroids_Professional.license -File)) {
    Write-Warning 'ISESteroids license file not found. Please contact Bryan Dady to obtain and install a license.'
}

write-output ' # loading ISESteroids # '; Start-Steroids;

write-output "`nCurrent PS execution policy is: "; Get-ExecutionPolicy -List | Format-Table -AutoSize;

if (Test-Path -Path $HOME\Documents\WindowsPowerShell\) {
    Set-Location -Path $HOME\Documents\WindowsPowerShell\;
} else {
    Set-Location -Path $env:USERPROFILE\Documents\WindowsPowerShell\
}
