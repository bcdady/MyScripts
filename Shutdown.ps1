#!/usr/local/bin/powershell
#Requires -Version 3
#========================================
# NAME      : Shutdown.ps1
# LANGUAGE  : Windows PowerShell
# AUTHOR    : Bryan Dady
# UPDATED   : 11/21/2017
# COMMENT   : To be used / invoked from a PowerShell profile script, to check for and use a network share (UNC) based $HOME, such as from a domain server
#========================================
[CmdletBinding(SupportsShouldProcess)]
param()
Set-StrictMode -Version latest

#Region MyScriptInfo
    Write-Verbose -Message '[Shutdown] Populating $MyScriptInfo'
    $script:MyCommandName        = $MyInvocation.MyCommand.Name
    $script:MyCommandPath        = $MyInvocation.MyCommand.Path
    $script:MyCommandType        = $MyInvocation.MyCommand.CommandType
    $script:MyCommandModule      = $MyInvocation.MyCommand.Module
    $script:MyModuleName         = $MyInvocation.MyCommand.ModuleName
    $script:MyCommandParameters  = $MyInvocation.MyCommand.Parameters
    $script:MyParameterSets      = $MyInvocation.MyCommand.ParameterSets
    $script:MyRemotingCapability = $MyInvocation.MyCommand.RemotingCapability
    $script:MyVisibility         = $MyInvocation.MyCommand.Visibility

    if (($null -eq $script:MyCommandName) -or ($null -eq $script:MyCommandPath)) {
        # We didn't get a successful command / script name or path from $MyInvocation, so check with CallStack
        Write-Verbose -Message "Getting PSCallStack [`$CallStack = Get-PSCallStack]"
        $CallStack = Get-PSCallStack | Select-Object -First 1
        # $CallStack | Select Position, ScriptName, Command | format-list # FunctionName, ScriptLineNumber, Arguments, Location
        $script:myScriptName = $CallStack.ScriptName
        $script:myCommand = $CallStack.Command
        Write-Verbose -Message "`$ScriptName: $script:myScriptName"
        Write-Verbose -Message "`$Command: $script:myCommand"
        Write-Verbose -Message 'Assigning previously null MyCommand variables with CallStack values'
        $script:MyCommandPath = $script:myScriptName
        $script:MyCommandName = $script:myCommand
    }

    #'Optimize New-Object invocation, based on Don Jones' recommendation: https://technet.microsoft.com/en-us/magazine/hh750381.aspx
    $Private:properties = [ordered]@{
        'CommandName'        = $script:MyCommandName
        'CommandPath'        = $script:MyCommandPath
        'CommandType'        = $script:MyCommandType
        'CommandModule'      = $script:MyCommandModule
        'ModuleName'         = $script:MyModuleName
        'CommandParameters'  = $script:MyCommandParameters.Keys
        'ParameterSets'      = $script:MyParameterSets
        'RemotingCapability' = $script:MyRemotingCapability
        'Visibility'         = $script:MyVisibility
    }
    $MyScriptInfo = New-Object -TypeName PSObject -Prop $properties
    Write-Verbose -Message '[Shutdown] $MyScriptInfo populated'
#End Region

Write-Output -InputObject " # Citrix Environment Shutdown ($($MyScriptInfo.CommandPath)) # "

#New-Variable -Name MyProcesses -ErrorAction Ignore
$MyKnownApps = @(
    'Code.exe',
    'CodeHelper.exe',
    'powershell_ise.exe',
    'lync.exe',
    'CommunicatorForLync2013.exe',
    'EXCEL.EXE',
    'ONENOTE.EXE',
    'ONENOTEM.EXE',
    'OUTLOOK.EXE',
    'VISIO.exe',
    'WINWORD.exe',
    'cmd.exe',
    'explorer.exe',
    'firefox.exe',
    'iexplore.exe',
    'SndVol.exe',
    'TaskMgr.exe',
    'regedit.exe',
    'g2mcomm.exe',
    'g2mstart.exe',
    'g2mlauncher.exe'
)

Write-Verbose -Message 'Declaring function Shutdown-XenApp'
function Shutdown-XenApp {
    [CmdletBinding()]
    param()
    Write-Warning -Message 'Shutting down XenApp Session'

    #if (MyProcesses.Length -gt 1) {
        $MyProcesses = Get-ProcessByUser | Sort-Object -Property ProcessID
    #}

    foreach ($app in ($MyProcesses | Sort-Object -Property ProcessID)) {
        if ($app.Name -in $MyKnownApps) {
            " # Stop App $($app.Name)"
            switch ($app.Name) {
                'outlook.exe' {
                    Write-Verbose -Message 'Quitting Outlook'
                    (New-Object -ComObject Outlook.Application).Quit()
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
                        Stop-Process -Id $ProcessID -PassThru -Confirm -ErrorAction Ignore
                    }
                }
            <#    
                'winword.exe' {
                    Write-Verbose -Message 'Quitting Word'
                    (New-Object -ComObject Word.Application).Quit()
                }
                'visio.exe' {
                    Write-Verbose -Message 'Quitting Visio'
                    (New-Object -ComObject Visio.Application).Quit()
                }
            #>
            }
            Start-Sleep -Seconds 1
        } else {
            " > Skipping App $($app.Name)"
        }
    }
    'Exit'
    #Exit # PowerShell
}
New-Alias -Name logoff -Value Shutdown-XenApp
New-Alias -Name xa_shutdown -Value Shutdown-XenApp


if (Get-Variable -Name MyProcesses -ErrorAction Ignore) {
  Write-Verbose -Message 'Found variable $MyProcesses'
} else {
  Write-Verbose -Message 'Getting my processes'
  $MyProcesses = Get-ProcessByUser
}

<#
    $MyProcesses | Select Name,ProcessID

    Name                                                                  ProcessID
    ----                                                                  ---------
    AppVStreamingUX.exe                                                       10392
    Citrix.CQI.exe                                                            22120
    Code.exe                                ...64,3164,9236,16148,16300,10916,20400
    CodeHelper.exe                                                            19804
    conhost.exe                                              20284,9248,12044,12368
    CtxMtHost.exe                                                              7708
    explorer.exe                                                    11988,8092,1148
    firefox.exe                                                               11404
    g2mcomm.exe                                                                9828
    g2mlauncher.exe                                                            8552
    g2mstart.exe                                                               9860
    iexplore.exe                            ...4,9392,20472,10164,13304,15728,20268
    ONENOTE.EXE                                                               16572
    ONENOTEM.EXE                                                               3748
    OUTLOOK.EXE                                                                9336
    powershell.exe                                                19348,21232,13868
    rundll32.exe                                             19732,3904,20784,18344
    SearchProtocolHost.exe                                                     7244
    SndVol.exe                                                                 9340
    taskhostex.exe                                                            15232
    VDARedirector.exe                                                          9916
    wfshell.exe                                                               14820
    winpty-agent.exe                                                     18664,2804
#>
