
# reg add HKLM\SYSTEM\CurrentControlSet\Control\StorageDevicePolicies /v WriteProtect /t REG_DWORD /d 0 /f
# reg add HKLM\SYSTEM\CurrentControlSet\Control\Storage /v Deny_Execute /t REG_DWORD /d 0 /f

# must be run with admin / elevated permissions
if ( -not (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')))
{
    Write-Output -InputObject 'Elevating via Open-AdminConsole -NoProfile'
    Open-AdminConsole -NoProfile -Command $($MyInvocation.MyCommand).Path
}

if ((Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\StorageDevicePolicies).WriteProtect -eq 1)
{
    Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\StorageDevicePolicies -Name WriteProtect -Value 0 -Force
}

if ((Get-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\Storage).Deny_Execute -eq 1)
{
    Set-ItemProperty -Path HKLM:\SYSTEM\CurrentControlSet\Control\Storage -Name Deny_Execute -Value 0 -Force
}

Get-ItemProperty -Path HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices\* -Name Deny_Write | foreach {
    if ($PSItem.Deny_Write -eq 1)
    {
        Set-ItemProperty -Path $PSItem.PSPath -Name Deny_Write -Value 0 -Force
    }
 }

(Get-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices\{F33FDC04-D1AC-4E8E-9A30-19BBD4B108AE}').Deny_Write
<#
Deny_Write   : 1
PSPath       : Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices
               \{F33FDC04-D1AC-4E8E-9A30-19BBD4B108AE}
PSParentPath : Microsoft.PowerShell.Core\Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Policies\Microsoft\Windows\RemovableStorageDevices
PSChildName  : {F33FDC04-D1AC-4E8E-9A30-19BBD4B108AE}
PSDrive      : HKLM
PSProvider   : Microsoft.PowerShell.Core\Registry
#>