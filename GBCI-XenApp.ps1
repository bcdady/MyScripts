#!/usr/local/bin/powershell
#Requires -Version 3
# PowerShell $Profile supplement script
# Bryan's GBCI / XenApp specific functions, aliases, and other conveniences, which don't belong directly in the profile script

# ~/.config/powershell/Microsoft.PowerShell_profile.ps1    

[cmdletbinding()]
Param()

$StartXenApp = Join-Path -Path $(Split-Path -Path $MyInvocation.MyCommand.Path -Parent) -ChildPath 'Start-XenApp.ps1' -Resolve -ErrorAction Stop
Write-Verbose -Message "Loading prerequisite functions from .\Start-XenApp.ps1"
. $StartXenApp

Write-Verbose -Message 'Loading functions from GBCI-XenApp.ps1'

Write-Verbose -Message 'Declaring function Logon-Work'
function Logon-Work
{
  Write-Output -InputObject 'Set-Workplace -zone Office'
  Set-ServiceGroup -ServiceName 'sophos client*' -Status Running
  Set-Workplace -zone Office
}

New-Alias -Name start-work -Value logon-work -ErrorAction SilentlyContinue

Write-Verbose -Message 'Declaring function Logoff-Work'
function Logoff-Work
{
  Write-Output -InputObject 'Set-Workplace -zone Remote'
  Set-ServiceGroup -ServiceName 'sophos client*' -Status Stopped
  Set-Workplace -zone Remote
}

New-Alias -Name stop-work -Value logoff-work -ErrorAction SilentlyContinue

Write-Verbose -Message 'Declaring function Open-Workfront'
function Open-Workfront
{
  if ($Global:onServer)
  {
    #Write-Output -InputObject 'https://glacierbancorp.my.workfront.com/myWork'
    #Start-Process -FilePath 'https://glacierbancorp.my.workfront.com/myWork'
    Write-Output -InputObject 'Open Infrastructure Tactical Status Dashboard in Workfront'
    Start-Process -FilePath 'https://glacierbancorp.my.workfront.com/dashboard/view?ID=58bf1adf0033326baa80cd030c403397'

<#    Write-Output -InputObject 'Open Workfront Training'
    #Start-Process -FilePath 'https://support.workfront.com/hc/en-us/articles/230791047?flash_digest=6bde06cf5b5f875b78fb38f7aba34a24533971ab#Workfront'
    Start-Process -FilePath explorer.exe -ArgumentList 'S:\Everyone\Workfront Training'
#>
  }
}

<#
  Available XenApp shortcuts as of 2017-05-31:
  H Drive
  XenApp 6 Farm
  Assyst
  Microsoft OneNote 2010
  Microsoft Excel 2010
  Remote Desktop Connection
  Firefox
  Citrix Director
  Internet Explorer
  Microsoft Visio 2010
  Microsoft Word 2010
  S Drive
  ThinPrint Self Service
  Adobe Reader XI
  IT Service Center
  UltiPro
  Microsoft Outlook 2010
  Skype for Business
#>

function xa_assyst
{
  if ($Global:onServer)
  {
    #Write-Output -InputObject 'https://assystweb/assystweb'
    #Start-Process -FilePath 'https://assystweb/assystweb'
    # New URL for SP7 Jan '17: https://gbci02aweb1/assystweb/application.do#eventsearch%2FEventSearchDelegatingDispatchAction.do%3Fdispatch%3DloadQuery%26showInMonitor%3Dtrue%26context%3Dselect%26queryProfileForm.columnProfileId%3D371%26queryProfileForm.queryProfileId%3D1216
    Write-Output -InputObject 'https://gbci02aweb1/assystweb/'
    Start-Process -FilePath 'https://gbci02aweb1/assystweb/'
  } else {
    # locally, via Receiver ...
    Write-Output -InputObject 'Start-XenApp -Qlaunch assyst'
    Start-XenApp -Qlaunch Assyst
  }
}

function xa_cmd
{
  # Start Command Line
  if ($Global:onServer) {
    Write-Output -InputObject '& cmd.exe'
    & cmd.exe
  } else {
    # locally, via Receiver ...
    Write-Output -InputObject 'Start-XenApp -Qlaunch cmd'
    Start-XenApp -Qlaunch cmd
  }
}

function xa_excel {
  if ($Global:onServer) {
    Write-Output -InputObject 'Microsoft Excel 2010.lnk'
    start-process -FilePath "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Office\Microsoft Excel 2010.lnk"
  } else {
    # locally, via Receiver ...
    Write-Output -InputObject 'Start-XenApp -Qlaunch Excel'
    Start-XenApp -Qlaunch 'Microsoft Excel 2010'
  }
}

Set-Alias -Name xa_xl -Value xa_excel

function xa_hdrive {
  if ($Global:onServer)
  {
    Write-Output -InputObject 'explorer.exe H:\'
    & explorer.exe 'H:\'
  }
  else
  {
    # locally, via Receiver ...
    Write-Output -InputObject 'Start-XenApp -Qlaunch "H Drive"'
    Start-XenApp -Qlaunch 'H Drive'
  }
}

Set-Alias -Name xa_explorer -Value xa_hdrive
Set-Alias -Name xa_h -Value xa_hdrive

function xa_IE
{
  if ($Global:onServer)
  {
    Write-Output -InputObject 'https://intranet2'
    Start-Process -FilePath 'https://intranet2'
  }
  else
  {
    # locally, via Receiver ...
    Write-Output -InputObject 'Start-XenApp -Qlaunch "Internet Explorer"'
    Start-XenApp -Qlaunch 'Internet Explorer'
  }
}

Set-Alias -Name xa_intranet -Value xa_ie
Set-Alias -Name xa_browser -Value xa_ie

function xa_itsc {
  if ($Global:onServer) {
    #    Write-Output -InputObject 'https://itsc/assystnet/'
    #    Start-Process -FilePath 'https://itsc/assystnet/'
    # New URL for SP7 Jan '17: https://gbci02itsc1/assystnet/application/assystNET.jsp#id=-1;;type=2
    Write-Output -InputObject 'https://gbci02itsc1/assystnet/'
    Start-Process -FilePath 'https://gbci02itsc1/assystnet/application/assystNET.jsp#id=-1;;type=2'
  } else {
    # locally, via Receiver ...
    Write-Output -InputObject 'Start-XenApp -Qlaunch "IT Service Center"'
    Start-XenApp -Qlaunch 'IT Service Center'
  }
}

function xa_firefox {
  Write-Output -InputObject 'Start-XenApp -Qlaunch Firefox'
  Start-XenApp -Qlaunch FireFox
}

function xa_mstsc {
  if ($Global:onServer)
  {
    Write-Output -InputObject 'Start-RemoteDesktop'
    Start-RemoteDesktop
  } else {
    Write-Output -InputObject 'Start-XenApp -Qlaunch mstsc'
    Start-XenApp -Qlaunch 'Remote Desktop Connection'
  }
}
Set-Alias -Name xa_rdp -Value xa_mstsc

function xa_onenote {
  if ($Global:onServer) {
    Write-Output -InputObject 'Microsoft OneNote 2010.lnk'
    start-process -FilePath "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Office\Microsoft OneNote 2010.lnk"
  } else {
    Write-Output -InputObject 'Start-XenApp -Qlaunch OneNote'
    Start-XenApp -Qlaunch 'Microsoft OneNote 2010'
  }
}

function xa_outlook {
  if ($Global:onServer) {
    Write-Output -InputObject 'Microsoft Outlook 2010.lnk'
    start-process -FilePath "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Office\Microsoft Outlook 2010.lnk"
  } else {
    Write-Output -InputObject 'Start-XenApp -Qlaunch outlook'
    Start-XenApp -Qlaunch 'Microsoft Outlook 2010'
  }
}

Set-Alias -Name xa_mail -Value xa_outlook
Set-Alias -Name xa_olk -Value xa_outlook

function xa_powerpoint {
  if ($Global:onServer) {
    Write-Output -InputObject 'Microsoft PowerPoint 2010.lnk'
    start-process -FilePath "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Office\Microsoft PowerPoint 2010.lnk"
  } else {
    Write-Output -InputObject 'Start-XenApp -Qlaunch powerpoint'
    Start-XenApp -Qlaunch 'Microsoft Powerpoint 2010' 
  }
}
Set-Alias -Name xa_ppt -Value xa_powerpoint

function xa_sdrive {
  if ($Global:onServer) {
    Write-Output -InputObject 'explorer.exe S:\'
    & explorer.exe 'S:\'
  } else {
    Write-Output -InputObject 'Start-XenApp -Qlaunch "S Drive"'
    Start-XenApp -Qlaunch 'S Drive'
  }
}
Set-Alias -Name xa_s -Value xa_sdrive

function xa_skype {
  if ($Global:onServer) {
    Write-Output -InputObject 'Skype for Business 2015.lnk'
    start-process -FilePath "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Office 2013\Skype for Business 2015.lnk"
  } else {
    Write-Output -InputObject 'Start-XenApp -Qlaunch "Skype for Business"'
    Start-XenApp -Qlaunch 'Skype for Business'
  }
}
Set-Alias -Name xa_s4b -Value xa_skype

function xa_synergy {
  if ($Global:onServer) {
    Write-Output -InputObject 'Synergy Desktop Manager.lnk'
    start-process -FilePath "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Synergy ECM\Synergy Desktop Manager.lnk"
  } else {
    # Qlaunch via Receiver
    Write-Output -InputObject 'Start-XenApp -Qlaunch synergy'
    Start-XenApp -Qlaunch synergy 
  }
}

function xa_synergy_admin
{
  if ($Global:onServer)
  {
    Write-Output -InputObject 'Synergy Administration.lnk'
    start-process -FilePath "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Synergy ECM\Synergy Administration.lnk"
  }
  else
  {
    Write-Output -InputObject 'Start-XenApp -Qlaunch Synergy Admin'
    # Qlaunch via Receiver
    Start-XenApp -Qlaunch synergy 
  }
}

function xa_visio
{
  if ($Global:onServer)
  {
    Write-Output -InputObject 'Microsoft Visio 2010.lnk'
    start-process -FilePath "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Office\Microsoft Visio 2010.lnk"
  }
  else
  {
    Write-Output -InputObject 'Start-XenApp -Qlaunch visio'
    Start-XenApp -Qlaunch visio 
  }
}
function xa_word
{
  if ($Global:onServer)
  {
    Write-Output -InputObject 'Microsoft Word 2010.lnk'
    start-process -FilePath "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Office\Microsoft Word 2010.lnk"
  }
  else
  {
    Write-Output -InputObject 'Start-XenApp -Qlaunch word'
    Start-XenApp -Qlaunch word
  }
}
function xa_adobe 
{
  if ($Global:onServer)
  {
    Write-Output -InputObject 'Adobe Reader XI.lnk'
    start-process -FilePath "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Adobe Reader XI.lnk"
  }
  else
  {
    Write-Output -InputObject 'H:\Desktop\Palo Alto Enterprise Security for Financial Services.PDF'
    & 'H:\Desktop\Palo Alto Enterprise Security for Financial Services.PDF'
  }
}
Set-Alias -Name xa_reader -Value xa_adobe
Set-Alias -Name xa_pdf -Value xa_adobe

function xa_reconnect
{
  Write-Output -InputObject 'Start-XenApp -Reconnect'
  Start-XenApp -Reconnect
}

function pa_start
{
  Write-Output -InputObject 'Start PortableApps'
  start-process -FilePath R:\it\Utilities\PortableApps\Start.exe
}

function xa_restart
{
  Write-Output -InputObject 'Restarting Citrix Receiver'
  Start-XenApp
  Get-Process -Name receiver | stop-process
  & "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Citrix\Receiver.lnk"
}

function Start-MyXenApps
{
  [cmdletbinding()]
  Param()

  # RFE: run this in the background?
  Write-Output -InputObject 'Starting Skype for Business'
  xa_skype
  Start-Sleep -Seconds 6
  Write-Output -InputObject"Setting GC92IT250 as default printer "
  # Set-Printer -printerShareName GC92IT250
  set-printer -printerShareName 'GC92IT250_(Grayscale)'
  Start-Sleep -Milliseconds 250
  get-printer -Default
  Start-Sleep -Seconds 1
  Write-Output -InputObject 'Starting OneNote'
  xa_onenote
  Start-Sleep -Seconds 5
  Write-Output -InputObject 'Starting Outlook'
  xa_outlook
  Start-Sleep -Seconds 3
  Write-Output -InputObject 'Opening Assyst, ITSC, and Workfront (in default browser)'
  xa_itsc
  Start-Sleep -Seconds 1
  xa_assyst
  Start-Sleep -Seconds 1
  open-workfront
}

Write-Verbose -Message 'Checking if work apps should be auto-started'
$thisHour = (Get-Date -DisplayHint Time).Hour
Write-Debug -Message "(-not [bool](Get-ProcessByUser -ProcessName 'outlook.exe'))"
if (($thisHour -ge 6) -and ($thisHour -le 18) -and ($Global:onServer) -and (-not [bool](Get-ProcessByUser -ProcessName 'outlook.exe')))
{
  Write-Verbose -Message 'Starting work apps'
  Write-output -InputObject ' # Default Printer # :'
  Get-Printer -Default
  
  Write-output -InputObject 'Start-MyXenApps'
  Start-MyXenApps
}
