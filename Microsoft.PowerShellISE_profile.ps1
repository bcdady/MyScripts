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

Write-Output -InputObject "`n`tLoading PowerShell `$Profile: CurrentUserCurrentHost_ISE`n"

# Moved HOME / MyPSHome, Modules, and Scripts variable determination to 
if (Test-Path -Path (Join-Path -Path (split-path -Path $MyInvocation.MyCommand.Path) -ChildPath 'bootstrap.ps1')) {
    . (Join-Path -Path (split-path -Path $MyInvocation.MyCommand.Path) -ChildPath 'bootstrap.ps1')
    if (Get-Variable -Name "myPS*" -ValueOnly -ErrorAction Ignore) {
        Write-Output -InputObject "My PowerShell Environment"
        Get-Variable -Name "myPS*" | Format-Table -AutoSize
    } else {
        throw "Failed to bootstrap: $(Join-Path -Path (split-path -Path $MyInvocation.MyCommand.Path) -ChildPath 'bootstrap.ps1')"
    }
} else {
    throw "Failed to locate profile-prerequisite bootstrap script: $(Join-Path -Path (split-path -Path $MyInvocation.MyCommand.Path) -ChildPath 'bootstrap.ps1')"
}

Write-Output -InputObject "PowerShell Execution Policy: "
Get-ExecutionPolicy -List | Format-Table -AutoSize

# ISERegex
#write-output -InputObject ' # loading ISERegex # '
#Start-ISERegex

# ShowDSCResource Add-On
Write-Verbose -Message ' # loading Show-DscResource Module #'
Import-Module -Name $myPSModulesPath\ShowDscResource\ShowDscResourceModule.psd1 -PassThru | Format-Table -AutoSize
& Install-DscResourceAddOn -Verbose

Start-Sleep -Seconds 1
Write-Verbose -Message ' # Checking ISESteroids license #'
if (-not [bool](Get-ChildItem -Path "$env:APPDATA\ISESteroids\License" -Name -Filter ISESteroids_Professional.license -File)) {
  Write-Warning -Message 'ISESteroids license file not found. Please contact Bryan Dady.'
}

# ISESteroids
Write-Verbose -Message ' # loading ISESteroids [Start-Steroids] #'
Start-Steroids
