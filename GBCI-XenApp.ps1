#!/usr/local/bin/powershell
#Requires -Version 3
# PowerShell $Profile supplement script
# Bryan's GBCI / XenApp specific functions, aliases, and other conveniences, which don't belong directly in the profile script

# ~/.config/powershell/Microsoft.PowerShell_profile.ps1    

[cmdletbinding(SupportsShouldProcess)]
Param()

write-output -inputobject 'Loading functions from GBCI-XenApp.ps1' -verbose

function Stop-Sophos
{
  Set-ServiceGroup -ServiceName 'sophos client*' -Status Stopped
}

function Start-Sophos
{
  Set-ServiceGroup -ServiceName 'sophos client*' -Status Running
}

function logon-work
{
  Write-Output -InputObject 'Set-Workplace -zone Office'
  Set-ServiceGroup -ServiceName 'sophos client*' -Status Running
  Set-Workplace -zone Office
}

New-Alias -Name start-work -Value logon-work -ErrorAction SilentlyContinue

function logoff-work
{
  Write-Output -InputObject 'Set-Workplace -zone Remote'
  Set-ServiceGroup -ServiceName 'sophos client*' -Status Stopped
  Set-Workplace -zone Remote
}

New-Alias -Name stop-work -Value logoff-work -ErrorAction SilentlyContinue

function open-workfront
{
  Write-Output -InputObject 'https://glacierbancorp.my.workfront.com/myWork'
  Start-Process -FilePath 'https://glacierbancorp.my.workfront.com/myWork'
}

function xa_assyst
{
  if ($onServer) 
  {
    #Write-Output -InputObject 'https://assystweb/assystweb'
    #Start-Process -FilePath 'https://assystweb/assystweb'
    # New URL for SP7 Jan '17: https://gbci02aweb1/assystweb/application.do#eventsearch%2FEventSearchDelegatingDispatchAction.do%3Fdispatch%3DloadQuery%26showInMonitor%3Dtrue%26context%3Dselect%26queryProfileForm.columnProfileId%3D371%26queryProfileForm.queryProfileId%3D1216
    Write-Output -InputObject 'https://gbci02aweb1/assystweb/'
    Start-Process -FilePath 'https://gbci02aweb1/assystweb/'
  }
  else
  {
    # locally, via Receiver ...
    Write-Output -InputObject 'Start-XenApp -Qlaunch assyst'
    Start-XenApp -Qlaunch assyst
  }
}
function xa_cmd
{
  # Start Command Line
  if ($onServer) 
  {
    Write-Output -InputObject '& cmd.exe'
    & cmd.exe
  }
  else
  {
    # locally, via Receiver ...
    Write-Output -InputObject 'Start-XenApp -Qlaunch cmd'
    Start-XenApp -Qlaunch cmd
  }
}
function xa_excel
{
  if ($onServer) 
  {
    Write-Output -InputObject 'Microsoft Excel 2010.lnk'
    start-process -FilePath "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Office\Microsoft Excel 2010.lnk"
  }
  else
  {
    # locally, via Receiver ...
    Write-Output -InputObject 'Start-XenApp -Qlaunch Excel'
    Start-XenApp -Qlaunch excel
  }
}

Set-Alias -Name xa_xl -Value xa_excel

function xa_hdrive
{
  if ($onServer) 
  {
    Write-Output -InputObject 'explorer.exe H:\'
    & explorer.exe 'H:\'
  }
  else
  {
    # locally, via Receiver ...
    Write-Output -InputObject 'Start-XenApp -Qlaunch h_drive'
    Start-XenApp -Qlaunch h_drive
  }
}

Set-Alias -Name xa_explorer -Value xa_hdrive
Set-Alias -Name xa_h -Value xa_hdrive

function xa_IE
{
  if ($onServer) 
  {
    Write-Output -InputObject 'https://intranet2'
    Start-Process -FilePath 'https://intranet2'
  }
  else
  {
    # locally, via Receiver ...
    Write-Output -InputObject 'Start-XenApp -Qlaunch IE'
    Start-XenApp -Qlaunch IE
  }
}

Set-Alias -Name xa_intranet -Value xa_ie
Set-Alias -Name xa_browser -Value xa_ie


function xa_itsc
{
  if ($onServer) 
  {
    #    Write-Output -InputObject 'https://itsc/assystnet/'
    #    Start-Process -FilePath 'https://itsc/assystnet/'
    # New URL for SP7 Jan '17: https://gbci02itsc1/assystnet/application/assystNET.jsp#id=-1;;type=2
    Write-Output -InputObject 'https://gbci02itsc1/assystnet/'
    Start-Process -FilePath 'https://gbci02itsc1/assystnet/application/assystNET.jsp#id=-1;;type=2'
  }
  else
  {
    # locally, via Receiver ...
    Write-Output -InputObject 'Start-XenApp -Qlaunch itsc'
    Start-XenApp -Qlaunch itsc
  }
}

function xa_firefox
{
  Write-Output -InputObject 'Start-XenApp -Qlaunch Firefox'
  Start-XenApp -Qlaunch FireFox
}
function xa_mstsc
{
  if ($onServer) 
  {
    Write-Output -InputObject 'Start-RemoteDesktop'
    Start-RemoteDesktop
  }
  else
  {
    Write-Output -InputObject 'Start-XenApp -Qlaunch mstsc'
    Start-XenApp -Qlaunch mstsc
  }
}
Set-Alias -Name xa_rdp -Value xa_mstsc

function xa_onenote 
{
  if ($onServer) 
  {
    Write-Output -InputObject 'Microsoft OneNote 2010.lnk'
    start-process -FilePath "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Office\Microsoft OneNote 2010.lnk"
  }
  else
  {
    Write-Output -InputObject 'Start-XenApp -Qlaunch onenote'
    Start-XenApp -Qlaunch onenote 
  }
}
function xa_outlook
{
  if ($onServer) 
  {
    Write-Output -InputObject 'Microsoft Outlook 2010.lnk'
    start-process -FilePath "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Office\Microsoft Outlook 2010.lnk"
  }
  else
  {
    Write-Output -InputObject 'Start-XenApp -Qlaunch outlook'
    Start-XenApp -Qlaunch outlook 
  }
}

Set-Alias -Name xa_mail -Value xa_outlook
Set-Alias -Name xa_olk -Value xa_outlook

function xa_powerpoint
{
  if ($onServer) 
  {
    Write-Output -InputObject 'Microsoft PowerPoint 2010.lnk'
    start-process -FilePath "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Office\Microsoft PowerPoint 2010.lnk"
  }
  else
  {
    Write-Output -InputObject 'Start-XenApp -Qlaunch powerpoint'
    Start-XenApp -Qlaunch powerpoint 
  }
}
Set-Alias -Name xa_ppt -Value xa_powerpoint

function xa_sdrive
{
  if ($onServer) 
  {
    Write-Output -InputObject 'explorer.exe S:\'
    & explorer.exe 'S:\'
  }
  else
  {
    Write-Output -InputObject 'Start-XenApp -Qlaunch s_drive'
    Start-XenApp -Qlaunch s_drive
  }
}
Set-Alias -Name xa_s -Value xa_sdrive

function xa_skype
{
  if ($onServer) 
  {
    Write-Output -InputObject 'Skype for Business 2015.lnk'
    start-process -FilePath "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Office 2013\Skype for Business 2015.lnk"
  }
  else
  {
    Write-Output -InputObject 'Start-XenApp -Qlaunch ''Skype for Business'''
    Start-XenApp -Qlaunch 'Skype for Business'
  }
}
Set-Alias -Name xa_s4b -Value xa_skype

<#
    PS .\> ls 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Synergy ECM\'


    Directory: C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Synergy ECM


    Mode                LastWriteTime     Length Name
    ----                -------------     ------ ----
    -a---         7/18/2015  11:49 PM       1126 Synergy Administration.lnk
    -a---         7/18/2015  11:47 PM       1120 Synergy Capture Client.lnk
    -a---         7/18/2015  11:47 PM       1109 Synergy Desktop Manager.lnk
    -a---         2/12/2016  10:48 AM       1105 Synergy User Client.lnk
#>

function xa_synergy
{
  if ($onServer) 
  {
    Write-Output -InputObject 'Synergy Desktop Manager.lnk'
    start-process -FilePath "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Synergy ECM\Synergy Desktop Manager.lnk"
  }
  else
  {
    # Qlaunch via Receiver
    Write-Output -InputObject 'Start-XenApp -Qlaunch synergy'
    Start-XenApp -Qlaunch synergy 
  }
}

function xa_synergy_admin
{
  if ($onServer) 
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
  if ($onServer) 
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
  if ($onServer)
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
  if ($onServer) 
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
  Get-Process -Name receiver | stop-process
  & "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Citrix\Receiver.lnk"
}

function Start-MyXenApps
{
  [cmdletbinding(SupportsShouldProcess)]
  Param()

  # RFE: run this in the background?
  Write-Verbose -Message 'Starting Skype for Business'
  xa_skype
  Start-Sleep -Seconds 5
  Write-Verbose -Message 'Starting OneNote'
  xa_onenote
  Start-Sleep -Seconds 5
  Write-Verbose -Message 'Starting H Drive'
  xa_h
  Start-Sleep -Seconds 2
  Write-Verbose -Message 'Starting Outlook'
  xa_outlook
  Start-Sleep -Seconds 5
  Write-Verbose -Message 'Opening Assyst, ITSC, and Workfront (in default browser)'
  xa_itsc
  Start-Sleep -Seconds 1
  xa_assyst
  Start-Sleep -Seconds 1
  open-workfront
}

Write-Verbose -Message 'Checking if work apps should be auto-started'
$thisHour = (Get-Date -DisplayHint Time).Hour
Write-Debug -Message "(-not [bool](Get-ProcessByUser -ProcessName 'outlook.exe'))"
if (($thisHour -ge 6) -and ($thisHour -le 18) -and ($onServer) -and (-not [bool](Get-ProcessByUser -ProcessName 'outlook.exe')))
{
  Write-output -InputObject ' # Default Printer # :'
  Get-Printer -Default
  
  Write-output -InputObject 'Start-MyXenApps'
  Start-MyXenApps
}
