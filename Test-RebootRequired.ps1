#!/usr/local/bin/pwsh
#Requires -Version 3
#========================================
# NAME      : Test-RebootRequired.ps1
# LANGUAGE  : Microsoft PowerShell
# Created to simplify testing of a Windows OS (especially server instances) for pending reboot conditions
#========================================
[CmdletBinding()]
param ()
#Set-StrictMode -Version latest

$RebootPending               = [bool](Test-Path -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending' -ErrorAction SilentlyContinue)
$RebootRequired              = [bool](Test-Path -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired' -ErrorAction SilentlyContinue)
$PendingFileRenameOperations = [bool](Get-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations' -ErrorAction SilentlyContinue)
$FileRenameOperations        = [bool](Get-Item -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\FileRenameOperations' -ErrorAction SilentlyContinue)

if ($RebootPending -or $RebootRequired -or $PendingFileRenameOperations -or $FileRenameOperations) {
  [System.Collections.ArrayList]$Reason = @()
  
  if ($RebootPending)  { $Reason.Add('Windows Servicing') }

  if ($RebootRequired) { $Reason.Add('Windows Update')}

  if ($PendingFileRenameOperations -or $FileRenameOperations) { $Reason.Add('File Rename Pending')}

  $Private:properties = [Ordered]@{
    'RebootRequired' = $true
    'Reason'         = $Reason
  }
  
  return (New-Object -TypeName PSObject -Property $Private:properties)
} else {
  return (New-Object -TypeName PSObject -Property ([Ordered]@{'RebootRequired' = $false; 'Reason' = $null}))
}
