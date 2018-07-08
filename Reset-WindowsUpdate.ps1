<# 
    .SYNOPSIS 
    Reset-WindowsUpdate.ps1 - Resets the Windows Update components 
    
    .DESCRIPTION  
    This script will reset all of the Windows Updates components to DEFAULT SETTINGS. 
    
    .OUTPUTS 
    Results are printed to the console. Future releases will support outputting to a log file.  
    
    .NOTES 
    Written by: Ryan Nemeth 
    
    Find me on: 
    
    * My Blog:    http://www.geekyryan.com 
    * Twitter:    https://twitter.com/geeky_ryan 
    * LinkedIn:    https://www.linkedin.com/in/ryan-nemeth-b0b1504b/ 
    * Github:    https://github.com/rnemeth90 
    * TechNet:  https://social.technet.microsoft.com/profile/ryan%20nemeth/ 
    
    Change Log 
    V1.00, 05/21/2015 - Initial version 
    V1.10, 09/22/2016 - Fixed bug with call to sc.exe 
    V1.20, 11/13/2017 - Fixed environment variables 
#> 
[CmdletBinding(SupportsShouldProcess)]
param()
Set-StrictMode -Version latest

Write-Output -InputObject ''
Write-Output -InputObject 'Reset-WindowsUpdate.ps1 - Resetting local Windows Update components'
Write-Output -InputObject ''
Write-Output -InputObject '1. Stopping Windows Update Services...' 
Stop-Service -Name BITS 
Stop-Service -Name wuauserv 
Stop-Service -Name appidsvc 
Stop-Service -Name cryptsvc 
 
Write-Output -InputObject ''
Write-Output -InputObject '2. Remove QMGR Data file...' 
Remove-Item -Path "$env:allusersprofile\Application Data\Microsoft\Network\Downloader\qmgr*.dat"
 
Write-Output -InputObject ''
Write-Output -InputObject ' 3. Renaming the Software Distribution and CatRoot Folder...' 
Rename-Item -Path $env:systemroot\SoftwareDistribution -NewName SoftwareDistribution.bak
Rename-Item -Path $env:systemroot\System32\Catroot2 -NewName catroot2.bak
 
Write-Output -InputObject ''
Write-Output -InputObject ' 4. Removing old Windows Update log...' 
Remove-Item -Path $env:systemroot\WindowsUpdate.log
 
Write-Output -InputObject ''
Write-Output -InputObject ' 5. Resetting the Windows Update Services to defualt settings...' 
& $env:systemroot\system32\sc.exe sdset bits 'D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)'
& $env:systemroot\system32\sc.exe sdset wuauserv 'D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)'
 
# Set-Location -Path $env:systemroot\system32 

Write-Output -InputObject ''
Write-Output -InputObject ' (Skip) 6. Re-register DLLs ...' 
<#
  Write-Output -InputObject ' 6. Registering some DLLs...' 
  regsvr32.exe /s atl.dll 
  regsvr32.exe /s urlmon.dll 
  regsvr32.exe /s mshtml.dll 
  regsvr32.exe /s shdocvw.dll 
  regsvr32.exe /s browseui.dll 
  regsvr32.exe /s jscript.dll 
  regsvr32.exe /s vbscript.dll 
  regsvr32.exe /s scrrun.dll 
  regsvr32.exe /s msxml.dll 
  regsvr32.exe /s msxml3.dll 
  regsvr32.exe /s msxml6.dll 
  regsvr32.exe /s actxprxy.dll 
  regsvr32.exe /s softpub.dll 
  regsvr32.exe /s wintrust.dll 
  regsvr32.exe /s dssenh.dll 
  regsvr32.exe /s rsaenh.dll 
  regsvr32.exe /s gpkcsp.dll 
  regsvr32.exe /s sccbase.dll 
  regsvr32.exe /s slbcsp.dll 
  regsvr32.exe /s cryptdlg.dll 
  regsvr32.exe /s oleaut32.dll 
  regsvr32.exe /s ole32.dll 
  regsvr32.exe /s shell32.dll 
  regsvr32.exe /s initpki.dll 
  regsvr32.exe /s wuapi.dll 
  regsvr32.exe /s wuaueng.dll 
  regsvr32.exe /s wuaueng1.dll 
  regsvr32.exe /s wucltui.dll 
  regsvr32.exe /s wups.dll 
  regsvr32.exe /s wups2.dll 
  regsvr32.exe /s wuweb.dll 
  regsvr32.exe /s qmgr.dll 
  regsvr32.exe /s qmgrprxy.dll 
  regsvr32.exe /s wucltux.dll 
  regsvr32.exe /s muweb.dll 
  regsvr32.exe /s wuwebv.dll 
#>
 
Write-Output -InputObject ''
Write-Output -InputObject ' 7. Removing WSUS client settings...' 
& "$env:windir\system32\reg.exe" DELETE 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate' /v AccountDomainSid /f 
& "$env:windir\system32\reg.exe" DELETE 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate' /v PingID /f 
& "$env:windir\system32\reg.exe" DELETE 'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate' /v SusClientId /f 
 
Write-Output -InputObject ''
Write-Output -InputObject ' 8. Resetting the WinSock...' 
& "$env:windir\system32\netsh.exe" winsock reset 
# & "$env:windir\system32\netsh.exe" winhttp reset proxy 
 
Write-Output -InputObject ''
Write-Output -InputObject ' 9. Delete all BITS jobs...' 
Get-BitsTransfer | Remove-BitsTransfer 

Write-Output -InputObject ''
Write-Output -InputObject ' (Skip) 10. Re-install the Windows Update Agent ...'
<#
  Write-Output -InputObject ' 10. Attempting to install the Windows Update Agent...' 

  #$arch = Get-WMIObject -Class Win32_Processor -ComputerName LocalHost | Select-Object -ExpandProperty AddressWidth 
  $arch = ((Get-WMIObject -Class Win32_Processor).AddressWidth | Select-Object -Unique)
  if($arch -eq 64){ 
      & "$env:windir\system32\wusa.exe" Windows8-RT-KB2937636-x64 /quiet 
  } 
  else{ 
      & "$env:windir\system32\wusa.exe" Windows8-RT-KB2937636-x86 /quiet 
  } 
#>
 
Write-Output -InputObject ''
Write-Output -InputObject ' 11. Starting Windows Update Services...' 
Start-Service -Name BITS 
Start-Service -Name wuauserv 
Start-Service -Name appidsvc 
Start-Service -Name cryptsvc 
 
Write-Output -InputObject ''
Write-Output -InputObject ' 12. DetectNow ...' 
# Deprecated in Windows Server 2016 -- https://docs.microsoft.com/en-us/windows-server/get-started/deprecated-features
# & "$env:windir\system32\wuauclt.exe" /resetauthorization /detectnow 

$AutoUpdates = New-Object -ComObject 'Microsoft.Update.AutoUpdate'
$AutoUpdates.DetectNow()
 
Write-Output -InputObject ''
Write-Output -InputObject 'Process complete. Please Restart Windows and try Updates again.'