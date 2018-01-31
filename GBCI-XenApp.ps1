#!/usr/local/bin/powershell
#Requires -Version 3 -Module Sperry
# PowerShell $Profile supplement script
# Bryan's GBCI / XenApp specific functions, aliases, and other conveniences, which don't belong directly in the profile script

[cmdletbinding()]
Param()

#Region MyScriptInfo
    Write-Verbose -Message '[GBCI-XenApp] Populating $MyScriptInfo'
    $Private:MyCommandName        = $MyInvocation.MyCommand.Name
    $Private:MyCommandPath        = $MyInvocation.MyCommand.Path
    $Private:MyCommandType        = $MyInvocation.MyCommand.CommandType
    $Private:MyCommandModule      = $MyInvocation.MyCommand.Module
    $Private:MyModuleName         = $MyInvocation.MyCommand.ModuleName
    $Private:MyCommandParameters  = $MyInvocation.MyCommand.Parameters
    $Private:MyParameterSets      = $MyInvocation.MyCommand.ParameterSets
    $Private:MyRemotingCapability = $MyInvocation.MyCommand.RemotingCapability
    $Private:MyVisibility         = $MyInvocation.MyCommand.Visibility

    if (($null -eq $Private:MyCommandName) -or ($null -eq $Private:MyCommandPath)) {
        # We didn't get a successful command / script name or path from $MyInvocation, so check with CallStack
        Write-Verbose -Message 'Getting PSCallStack [$CallStack = Get-PSCallStack]'
        $Private:CallStack      = Get-PSCallStack | Select-Object -First 1
        # $CallStack | Select Position, ScriptName, Command | format-list # FunctionName, ScriptLineNumber, Arguments, Location
        $Private:myScriptName   = $Private:CallStack.ScriptName
        $Private:myCommand      = $Private:CallStack.Command
        Write-Verbose -Message "`$ScriptName: $Private:myScriptName"
        Write-Verbose -Message "`$Command: $Private:myCommand"
        Write-Verbose -Message 'Assigning previously null MyCommand variables with CallStack values'
        $Private:MyCommandPath  = $Private:myScriptName
        $Private:MyCommandName  = $Private:myCommand
    }

    #'Optimize New-Object invocation, based on Don Jones' recommendation: https://technet.microsoft.com/en-us/magazine/hh750381.aspx
    $Private:properties = [ordered]@{
        'CommandName'        = $Private:MyCommandName
        'CommandPath'        = $Private:MyCommandPath
        'CommandType'        = $Private:MyCommandType
        'CommandModule'      = $Private:MyCommandModule
        'ModuleName'         = $Private:MyModuleName
        'CommandParameters'  = $Private:MyCommandParameters.Keys
        'ParameterSets'      = $Private:MyParameterSets
        'RemotingCapability' = $Private:MyRemotingCapability
        'Visibility'         = $Private:MyVisibility
    }
    $MyScriptInfo = New-Object -TypeName PSObject -Property $Private:properties
    Write-Verbose -Message '[GBCI-XenApp] $MyScriptInfo populated'

    if ('Verbose' -in $PSBoundParameters.Keys) {
        Write-Verbose -Message 'Output Level is [Verbose]. $MyScriptInfo is:'
        $MyScriptInfo
    }
#End Region

# $StartXenApp = Join-Path -Path $(Split-Path -Path $MyInvocation.MyCommand.Path -Parent) -ChildPath 'Start-XenApp.ps1' -Resolve -ErrorAction Stop
Write-Verbose -Message 'Loading prerequisite functions from .\Start-XenApp.ps1'
. (Join-Path -Path (Split-Path -Path $MyScriptInfo.CommandPath -Parent) -ChildPath Start-XenApp.ps1) -ErrorAction Stop

Write-Verbose -Message 'Loading functions from GBCI-XenApp.ps1'

# Define MyProcesses variable so it can be referenced within and across functions
Set-Variable -Name MyProcesses #-Option AllScope

Write-Verbose -Message 'Declaring function Logon-Work'
function Logon-Work {
  Write-Output -InputObject 'Set-Workplace -zone Office'
  if (-not $Global:onServer) {
    Set-ServiceGroup -ServiceName '*firewall*' -Status Running
  }
  Set-Workplace -zone Office
}

New-Alias -Name start-work -Value logon-work -ErrorAction SilentlyContinue

Write-Verbose -Message 'Declaring function Logoff-Work'
function Logoff-Work {
  Write-Output -InputObject 'Set-Workplace -zone Remote'
  Set-ServiceGroup -ServiceName '*firewall*' -Status Stopped
  Set-Workplace -zone Remote
}

New-Alias -Name stop-work -Value logoff-work -ErrorAction SilentlyContinue

Write-Verbose -Message 'Declaring function Open-MyWebPages'
function Open-MyWebPages {
  #xa_IE
  xa_firefox
  if ($Global:onServer) {

    Write-Output -InputObject 'Open SecurityCenter'
    Start-Process -FilePath 'https://gbci02sc01/'
    Start-Sleep -Seconds 2

    Write-Output -InputObject 'Open Splunk-Ops'
    Start-Process -FilePath 'https://splunk-ops:8000/'
    Start-Sleep -Seconds 2
    
    # Write-Output -InputObject 'Open Michael Hyatt''s Free to Focus'
    # Start-Process -FilePath 'https://courses.michaelhyatt.com/freetofocus'
    # Start-Sleep -Seconds 2
    
    # Write-Output -InputObject 'Open Nozbe'
    # Start-Process -FilePath 'https://app.nozbe.com/'

    #Write-Output -InputObject 'https://glacierbancorp.my.workfront.com/myWork'
    #Start-Process -FilePath 'https://glacierbancorp.my.workfront.com/myWork'
    Write-Output -InputObject 'Open Infrastructure Tactical Status Dashboard in Workfront'
    Start-Process -FilePath 'https://glacierbancorp.my.workfront.com/dashboard/view?ID=58bf1adf0033326baa80cd030c403397'
    # Write-Output -InputObject 'Open Workfront Notifications'
    # Start-Process -FilePath 'https://glacierbancorp.my.workfront.com/user/notifications'
    #Write-Output -InputObject 'Open Workfront Training'
    #Start-Process -FilePath 'https://support.workfront.com/hc/en-us/articles/230791047?flash_digest=6bde06cf5b5f875b78fb38f7aba34a24533971ab#Workfront'
    #Start-Process -FilePath explorer.exe -ArgumentList 'S:\Everyone\Workfront Training'
  }
}

function xa_assyst {
  if ($Global:onServer) {
    #Write-Output -InputObject 'https://assystweb/assystweb'
    #Start-Process -FilePath 'https://assystweb/assystweb'
    # New URL for SP7 Jan '17: https://gbci02aweb1/assystweb/application.do#eventsearch%2FEventSearchDelegatingDispatchAction.do%3Fdispatch%3DloadQuery%26showInMonitor%3Dtrue%26context%3Dselect%26queryProfileForm.columnProfileId%3D371%26queryProfileForm.queryProfileId%3D1216
    Write-Output -InputObject 'https://gbci02aweb1/assystweb/'
    Start-Process -FilePath 'https://gbci02aweb1/assystweb/'
  } else {
    # locally, via Receiver ...
    Write-Output -InputObject 'Start-XenApp -QLaunch assyst'
    Start-XenApp -QLaunch Assyst
  }
}

function xa_cmd {
  # Start Command Line
  if ($Global:onServer) {
    Write-Output -InputObject "& $env:ComSpec"
    & "$env:ComSpec"
  } else {
    # locally, via Receiver ...
    Write-Output -InputObject 'Start-XenApp -QLaunch cmd'
    Start-XenApp -QLaunch cmd
  }
}

function xa_excel {
  if ($Global:onServer) {
    Write-Output -InputObject 'Microsoft Excel 2010.lnk'
    start-process -FilePath "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Office\Microsoft Excel 2010.lnk"
  } else {
    # locally, via Receiver ...
    Write-Output -InputObject 'Start-XenApp -QLaunch Excel'
    Start-XenApp -QLaunch 'Microsoft Excel 2010'
  }
}

Set-Alias -Name xa_xl -Value xa_excel

function xa_hdrive {
  if ($Global:onServer) {
    Write-Output -InputObject "explorer.exe $env:HOMEDRIVE\"
    & "$env:windir\explorer.exe" "$env:HOMEDRIVE\"
  } else {
    # locally, via Receiver ...
    Write-Output -InputObject 'Start-XenApp -QLaunch "H Drive"'
    Start-XenApp -QLaunch 'H Drive'
  }
}

Set-Alias -Name xa_explorer -Value xa_hdrive
Set-Alias -Name xa_h -Value xa_hdrive

function xa_IE {
  if ($Global:onServer) {
    Write-Output -InputObject 'https://intranet2'
    Start-Process -FilePath 'https://intranet2'
  } else {
    # locally, via Receiver ...
    Write-Output -InputObject 'Start-XenApp -QLaunch "Internet Explorer"'
    Start-XenApp -QLaunch 'Internet Explorer'
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
    Write-Output -InputObject 'Start-XenApp -QLaunch "IT Service Center"'
    Start-XenApp -QLaunch 'IT Service Center'
  }
}

function xa_firefox {
  if ($Global:onServer) {
    Write-Output -InputObject 'Firefox.exe'
    & "${env:ProgramFiles(x86)}\Mozilla Firefox\firefox.exe"
    
  } else {
    Write-Output -InputObject 'Start-XenApp -QLaunch Firefox'
    Start-XenApp -QLaunch FireFox
  }
}

function xa_mstsc {
  if ($Global:onServer) {
    Write-Output -InputObject 'Start-RemoteDesktop'
    Start-RemoteDesktop
  } else {
    Write-Output -InputObject 'Start-XenApp -QLaunch mstsc'
    Start-XenApp -QLaunch 'Remote Desktop Connection'
  }
}
Set-Alias -Name xa_rdp -Value xa_mstsc

function xa_onenote {
  if ($Global:onServer) {
    Write-Output -InputObject 'Microsoft OneNote 2010.lnk'
    start-process -FilePath "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Office\Microsoft OneNote 2010.lnk"
  } else {
    Write-Output -InputObject 'Start-XenApp -QLaunch OneNote'
    Start-XenApp -QLaunch 'Microsoft OneNote 2010'
  }
}

function xa_outlook {
  if ($Global:onServer) {
    Write-Output -InputObject 'Microsoft Outlook 2010'
    if (Test-Path -Path "$env:ProgramFiles\Microsoft Office\Office14\OUTLOOK.EXE") {
        Write-Output -InputObject 'Opening Outlook Calendar'
        & "$env:ProgramFiles\Microsoft Office\Office14\OUTLOOK.EXE" /select outlook:calendar
    } else {
        start-process -FilePath "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Office\Microsoft Outlook 2010.lnk"
    }
  } else {
    Write-Output -InputObject 'Start-XenApp -QLaunch outlook'
    Start-XenApp -QLaunch 'Microsoft Outlook 2010'
  }
}

Set-Alias -Name xa_mail -Value xa_outlook
Set-Alias -Name xa_olk -Value xa_outlook

function xa_powerpoint {
  if ($Global:onServer) {
    Write-Output -InputObject 'Microsoft PowerPoint 2010.lnk'
    start-process -FilePath "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Office\Microsoft PowerPoint 2010.lnk"
  } else {
    Write-Output -InputObject 'Start-XenApp -QLaunch powerpoint'
    Start-XenApp -QLaunch 'Microsoft Powerpoint 2010' 
  }
}
Set-Alias -Name xa_ppt -Value xa_powerpoint

function xa_sdrive {
  if ($Global:onServer) {
    Write-Output -InputObject 'explorer.exe S:\'
    & "$env:windir\explorer.exe" 'S:\'
  } else {
    Write-Output -InputObject 'Start-XenApp -QLaunch "S Drive"'
    Start-XenApp -QLaunch 'S Drive'
  }
}
Set-Alias -Name xa_s -Value xa_sdrive

function xa_skype {
  if ($Global:onServer) {
    if (((Get-ProcessByUser -ProcessName CommunicatorForLync*).Owner) -eq 'bdady') {
      Write-Output -InputObject 'Skype for Business 2015.lnk'
      Start-Process -FilePath "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Office 2013\Skype for Business 2015.lnk"
    } else {
      Write-Verbose -Message 'Skype for Business is already running' -Verbose
    }
  } else {
    Write-Output -InputObject 'Start-XenApp -QLaunch "Skype for Business"'
    Start-XenApp -QLaunch 'Skype for Business'
  }
}
Set-Alias -Name xa_s4b -Value xa_skype

function xa_synergy {
  if ($Global:onServer) {
    Write-Output -InputObject 'Synergy Desktop Manager.lnk'
    start-process -FilePath "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Synergy ECM\Synergy Desktop Manager.lnk"
  } else {
    # Qlaunch via Receiver
    Write-Output -InputObject 'Start-XenApp -QLaunch synergy'
    Start-XenApp -QLaunch synergy 
  }
}

function xa_synergy_admin {
  if ($Global:onServer) {
    Write-Output -InputObject 'Synergy Administration.lnk'
    start-process -FilePath "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Synergy ECM\Synergy Administration.lnk"
  } else {
    Write-Output -InputObject 'Start-XenApp -QLaunch Synergy Admin'
    # Qlaunch via Receiver
    Start-XenApp -QLaunch synergy 
  }
}

function xa_visio {
  if ($Global:onServer) {
    Write-Output -InputObject 'Microsoft Visio 2010.lnk'
    start-process -FilePath "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Office\Microsoft Visio 2010.lnk"
  } else {
    Write-Output -InputObject 'Start-XenApp -QLaunch visio'
    Start-XenApp -QLaunch 'Microsoft Visio 2010' 
  }
}

function xa_word {
  if ($Global:onServer) {
    Write-Output -InputObject 'Microsoft Word 2010.lnk'
    start-process -FilePath "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Microsoft Office\Microsoft Word 2010.lnk"
  } else {
    Write-Output -InputObject 'Start-XenApp -QLaunch word'
    Start-XenApp -QLaunch 'Microsoft Word 2010'
  }
}

function xa_adobe {
  if ($Global:onServer) {
    Write-Output -InputObject 'Adobe Reader XI.lnk'
    start-process -FilePath "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Adobe Reader XI.lnk"
  } else {
    Write-Output -InputObject "$env:DESKTOP\Palo Alto Enterprise Security for Financial Services.PDF"
    & "$env:DESKTOP\Palo Alto Enterprise Security for Financial Services.PDF"
  }
}
Set-Alias -Name xa_reader -Value xa_adobe
Set-Alias -Name xa_pdf -Value xa_adobe

function xa_reconnect {
  Write-Output -InputObject 'Start-XenApp -Reconnect'
  Start-XenApp -Reconnect
}

function pa_start {
  Write-Output -InputObject 'Start PortableApps'
  start-process -FilePath R:\it\Utilities\PortableApps\Start.exe
}

function xa_restart {
  Write-Output -InputObject 'Restarting Citrix Receiver'
  Start-XenApp
  Get-Process -Name receiver | stop-process
  & "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Citrix\Receiver.lnk"
}

Write-Verbose -Message 'Declaring function Start-MyXenApps'
function Start-MyXenApps {
    [cmdletbinding()]
    Param()

    # RFE: run this in the background?
    #  Write-Output -InputObject 'Starting Skype for Business'
    #  xa_skype
    #  Start-Sleep -Seconds 6
    Write-Output -InputObject 'Opening Desktop folder'
    & "$env:windir\explorer.exe" "$env:DESKTOP"
    Write-Output -InputObject 'Starting OneNote'
    xa_onenote
    Start-Sleep -Seconds 3
    Write-Output -InputObject 'Opening Firefox'
    xa_firefox
    #  Start-Sleep -Seconds 5
    #  Write-Output -InputObject 'Opening Assyst, ITSC, and Workfront (in default browser)'
    #  xa_itsc
    #  Start-Sleep -Seconds 2
    #  xa_assyst
    #  Start-Sleep -Seconds 1
    #  Open-MyWebPages
    #  Start-Sleep -Seconds 30
    #  Write-Output -InputObject "Setting GC92IT250_(Grayscale) as default printer"
    #  Set-Printer -printerShareName 'GC92IT250_(Grayscale)'
    Start-Sleep -Milliseconds 250
    get-printer -Default
    Start-Sleep -Seconds 1
    & "$env:windir\system32\sndvol.exe"
    Start-Sleep -Seconds 5
    Write-Output -InputObject 'Starting Outlook'
    xa_outlook
}

$MyKnownApps = @(
    'AcroRd32.exe', 'NuancePDF.exe',
    'Code.exe', 'CodeHelper.exe', 'powershell_ise.exe',
    'lync.exe', 'CommunicatorForLync2013.exe', 'firefox.exe',
    'EXCEL.EXE', 'ONENOTE.EXE', 'ONENOTEM.EXE', 'OUTLOOK.EXE', 'VISIO.exe', 'WINWORD.exe',
    'cmd.exe', 'explorer.exe', 'iexplore.exe', 'regedit.exe',
    'SndVol.exe', 'TaskMgr.exe', 
    'g2mcomm.exe', 'g2mstart.exe', 'g2mlauncher.exe'
)

Write-Verbose -Message 'Declaring function Stop-MyXenApps'
function Stop-MyXenApps {
    [CmdletBinding()]
    Param()

    if ($onServer) {
        Write-Output -InputObject ' # Citrix Environment Shutdown #'
        Write-Verbose -Message " # $($MyScriptInfo.CommandPath) #"
        
        Write-Warning -Message ' # Open Citrix Connection Center #'
        Start-Sleep -Seconds 5

        Write-Output -InputObject 'Shutting down XenApp Session'

        if (Get-Variable -Name MyProcesses -ErrorAction Ignore) {
            Write-Verbose -Message 'Found variable $MyProcesses'
        } else {
            Write-Verbose -Message 'Getting my processes'
            $MyProcesses = Get-ProcessByUser
            $MyProcessesDateTime = $now
        }

        foreach ($app in ($MyProcesses | Sort-Object -Property ProcessID)) {
            if ($app.Name -in $MyKnownApps) {
                " # Stop App $($app.Name)"
                switch ($app.Name) {
                    'outlook.exe' {
                        Write-Verbose -Message 'Quitting Outlook'
                        (New-Object -ComObject Outlook.Application).Quit()
                    }
                    'Code.exe' {
                        foreach ($ProcessID in $($app.ProcessID -split ',')) {
                            " ! Stop process $ProcessID"
                            Stop-Process -Id $ProcessID -PassThru -Confirm -ErrorAction Ignore
                        }
                    }
                    'powershell_ise.exe' {
                        foreach ($ProcessID in $($app.ProcessID -split ',')) {
                            " ! Stop process $ProcessID"
                            Stop-Process -Id $ProcessID -PassThru -Confirm -ErrorAction Ignore
                        }
                    }
                    'EXCEL.EXE' {
                        foreach ($ProcessID in $($app.ProcessID -split ',')) {
                            " ! Stop process $ProcessID"
                            Stop-Process -Id $ProcessID -PassThru -Confirm -ErrorAction Ignore
                        }
                    }
                    'VISIO.exe' {
                        foreach ($ProcessID in $($app.ProcessID -split ',')) {
                            " ! Stop process $ProcessID"
                            Stop-Process -Id $ProcessID -PassThru -Confirm -ErrorAction Ignore
                        }
                    }
                    'WINWORD.exe' {
                        foreach ($ProcessID in $($app.ProcessID -split ',')) {
                            " ! Stop process $ProcessID"
                            Stop-Process -Id $ProcessID -PassThru -Confirm -ErrorAction Ignore
                        }
                    }
                    'NuancePDF.exe' {
                        foreach ($ProcessID in $($app.ProcessID -split ',')) {
                            " ! Stop process $ProcessID"
                            Stop-Process -Id $ProcessID -PassThru -Confirm -ErrorAction Ignore
                        }
                    }
                    'firefox.exe' {
                        foreach ($ProcessID in $($app.ProcessID -split ',')) {
                            " ! Stop process $ProcessID"
                            Stop-Process -Id $ProcessID -PassThru -Confirm -ErrorAction Ignore
                        }
                    }
                    'g2mstart.exe' {
                        Write-Verbose -Message 'Quitting GoToMeeting'
                        taskkill.exe /F /IM "g2mstart.exe" 
                    }
                    'g2mlauncher.exe' {
                        Write-Verbose -Message 'Quitting GoToMeeting'
                        taskkill.exe /F /IM "g2mlauncher.exe" 
                    }
                    'g2mcomm.exe' {
                        Write-Verbose -Message 'Quitting GoToMeeting'
                        taskkill.exe /F /IM "g2mcomm.exe" 
                    }
                    Default {
                        foreach ($ProcessID in $($app.ProcessID -split ',')) {
                            " ! Stop process $ProcessID"
                            Stop-Process -Id $ProcessID -PassThru
                        }
                    }
                }
                Start-Sleep -Seconds 1
            } else {
                " > Skipping App $($app.Name)"
            }
        }

        $MyProcessesDoubleCheck = Get-ProcessByUser
        if ($MyProcessesDoubleCheck -eq $MyProcesses) {
            # it seems something didn't go right, if we still have all the same apps / processes running
            Write-Warning -Message 'No change detected in running apps. You likely need to try again.'
        } else {
            Write-Output -InputObject 'Exit'
            Start-Sleep -Seconds 5
            Exit # PowerShell
        }

    } else {
        # Reset / refresh PowerShell environment variables to local system
        # Set Verbose host output Preference
        $VerbosePreference = 'Continue'
        Remove-Variable -Name myPS*
        Dismount-Path -Confirm

        if (Test-Path -Path $HOME) {
            Write-Verbose -Message ('{0} is still available' -f $HOME)
        } else {
            if (Test-Path -Path $env:USERPROFILE) {
                Write-Verbose -Message ('Updating {0} to {1}' -f $HOME, $env:USERPROFILE)
                Set-Variable -Name HOME -Scope Global -Value $env:USERPROFILE -Force
            } else {
                Write-Verbose -Message ('Unable to update {0} to {1}' -f $HOME, $env:USERPROFILE)
            }
        }

        # reload/invoke bootstrap
        Write-Verbose -Message '(Test-Path -Path (Join-Path -Path (Resolve-Path -Path ("$env:USERPROFILE\*Documents\WindowsPowerShell")) -ChildPath "bootstrap.ps1"))'
        Write-Verbose -Message (Test-Path -Path (Join-Path -Path (Resolve-Path -Path ("$env:USERPROFILE\*Documents\WindowsPowerShell")) -ChildPath 'bootstrap.ps1'))

        if (Test-Path -Path (Join-Path -Path (Resolve-Path -Path ("$env:USERPROFILE\*Documents\WindowsPowerShell")) -ChildPath 'bootstrap.ps1')) {
            $bootstrap = (Join-Path -Path (Resolve-Path -Path ("$env:USERPROFILE\*Documents\WindowsPowerShell")) -ChildPath 'bootstrap.ps1')
            . $bootstrap 
            if (Get-Variable -Name 'myPS*' -ValueOnly -ErrorAction Ignore) {
                Write-Output -InputObject ''
                Write-Output -InputObject 'My PowerShell Environment:'
                Get-Variable -Name 'myPS*' | Format-Table
            } else {
                Write-Warning -Message 'Failed to enumerate My PowerShell Environment as should have been initialized by bootstrap script'
            }
        } else {
            throw ('Failed to bootstrap: {0}\bootstrap.ps1' -f ("$env:USERPROFILE\*Documents\WindowsPowerShell"))
        }
        #(Resolve-Path -Path ("$env:USERPROFILE\*Documents\WindowsPowerShell"))

        Write-Verbose -Message '(Test-Path -Path (Join-Path -Path (Resolve-Path -Path ("$env:USERPROFILE\*Documents\WindowsPowerShell")) -ChildPath "bootstrap.ps1"))'
        Write-Verbose -Message (Test-Path -Path (Join-Path -Path (Resolve-Path -Path ("$env:USERPROFILE\*Documents\WindowsPowerShell")) -ChildPath 'bootstrap.ps1'))
    
        # Reset Verbose host output Preference
        $VerbosePreference = 'SilentlyContinue'
        
        if ($Global:onServer) {
            Write-Output -InputObject 'Logoff.exe'
            Start-Sleep -Seconds 5
            & $env:windir\system32\logoff.exe /v
        }
    }
}
New-Alias -Name logoff -Value Stop-MyXenApps
New-Alias -Name xa_shutdown -Value Stop-MyXenApps
