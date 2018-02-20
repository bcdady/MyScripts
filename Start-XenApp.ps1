#Requires -Version 3 -Module CimCmdlets, PSLogger, Sperry
# Enhanced May 2017 to support XenApp 7 and StoreFront
[cmdletbinding()]
Param()

#Region MyScriptInfo
    Write-Verbose -Message '[Start-XenApp] Populating $MyScriptInfo'
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
    New-Variable -Name MyScriptInfo -Value (New-Object -TypeName PSObject -Property $Private:properties) -Scope Local -Option AllScope -Force
    Write-Verbose -Message '[Start-XenApp] $MyScriptInfo populated'

    # Cleanup
    foreach ($var in $Private:properties.Keys) {
        Remove-Variable -Name ('My{0}' -f $var) -Force
    }

    $IsVerbose = $false
    if ('Verbose' -in $PSBoundParameters.Keys) {
        Write-Verbose -Message 'Output Level is [Verbose]. $MyScriptInfo is:'
        $IsVerbose = $true
        $Private:MyScriptInfo
    }
#End Region

# Define Shared variables at the script root so they can be (re-)used across functions
Set-Variable -Name CitrixName    -Value $NULL -Scope Script -Option AllScope
Set-Variable -Name CitrixVersion -Value $NULL -Scope Script -Option AllScope
Set-Variable -Name ICAClient     -Value $NULL -Scope Script -Option AllScope
#Set-Variable -Name CitrixVer     -Value $NULL -Scope Script -Option AllScope

Write-Verbose -Message 'Declaring function Start-CitrixSession'
function Start-CitrixSession {
    [CmdletBinding()]
    param ()
    Show-Progress -msgAction 'Start' -msgSource $MyInvocation.MyCommand.Name # Log start time stamp

    if ((-not (Get-Variable -Name onServer -Scope Global -ErrorAction SilentlyContinue)) -OR ($NULL -ne $onServer)) {
        $Global:onServer = $false
        if ((Get-WmiObject -Class Win32_OperatingSystem -Property Caption).Caption -like '*Windows Server*') {
            $Global:onServer = $true
        }
    }

    if ((-not (Get-Process -Name Receiver -ErrorAction SilentlyContinue)) -and (-not $Global:onServer)) {
        if (Test-Path -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\*Citrix Receiver.lnk") {
            "Starting Citrix Receiver: ($((Resolve-Path -Path ""$env:ProgramData\Microsoft\Windows\Start Menu\Programs\*Citrix Receiver.lnk"").Path))"
            & (Resolve-Path -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\*Citrix Receiver.lnk").Path
            ' ... '
            Start-Sleep -Seconds 3
        }
    } else {
        Write-Log -Message 'Confirmed Citrix Receiver is running.' -Function $MyInvocation.MyCommand.Name
    }

    # Check if running on server or in client (Citrix Receiver) context
    if (-not ($Global:onServer)) {
        # Confirm Citrix XenApp shortcuts are available, and then launch frequently used apps
        if (test-path -Path "$env:USERPROFILE\Desktop\Assyst.lnk" -PathType Leaf) {
            Write-Output -InputObject 'Starting Citrix session ("H Drive")'
            Start-XenApp -Qlaunch 'H Drive'
            Write-Output -InputObject 'Pausing for Citrix (XenApp) session to load ...'
            Start-Sleep -Seconds 60
            Write-Output -InputObject 'Starting Skype for Business'
            Start-XenApp -Qlaunch 'Skype for Business'
            Start-Sleep -Seconds 10
            Write-Output -InputObject 'Starting Outlook Web Access'
            Start-XenApp -Qlaunch 'Outlook Web Access'
            
            # Write-Output -InputObject 'Starting Firefox (XenApp)'
            # xa_firefox
        } else {
            Write-Log -Message 'Unable to locate XenApp shortcuts. Please check network connectivity to workplace resources and try again.' -Function $MyInvocation.MyCommand.Name -Verbose
        }
    }

    Write-Verbose -Message 'Checking if work apps should be auto-started'
    $thisHour = (Get-Date -DisplayHint Time).Hour
    Write-Debug -Message "(-not [bool](Get-ProcessByUser -ProcessName 'outlook.exe'))"
    if (($thisHour -ge 6) -and ($thisHour -le 18) -and ($Global:onServer) -and (-not [bool](Get-ProcessByUser -ProcessName 'outlook.exe' -ErrorAction Ignore))) {
        Write-Verbose -Message 'Starting work apps'
        Write-Output -InputObject 'Start-MyXenApps'
        Start-MyXenApps
        Write-Output -InputObject " # Default Printer # : $((Get-Printer -Default | Select-Object -ExpandProperty ShareName).ShareName)"
    } else {
        Write-Verbose -Message ('$thisHour: {0}' -f $thisHour)
        Write-Verbose -Message ('$Global:onServer : {0}' -f $Global:onServer)
        Write-Verbose -Message "Get-ProcessByUser -ProcessName 'outlook.exe': $([bool](Get-ProcessByUser -ProcessName 'outlook.exe' -ErrorAction Ignore))"
    }

    Show-Progress -msgAction 'Stop' -msgSource $MyInvocation.MyCommand.Name # Log end time stamp
    return $true # (Get-Process -Name Receiver).Description
}

Write-Verbose -Message 'Declaring function Get-SystemCitrixInfo'
function Get-SystemCitrixInfo {
    <#
        .SYNOPSIS
            Enumerate and retrieve essential information about the host system and it's Citrix components

        .DESCRIPTION
            Returns the SystemName (ComputerName), SystemType (OS Edition, or Client / Server), Citrix product Display Name and Version
        .EXAMPLE
            PS .\> Get-SystemCitrixInfo | FL

            DisplayName    : Citrix Virtual Delivery Agent 7.13
            DisplayVersion : 7.13.0.84
            SystemName     : GBCI02CXC004
            SystemType     : Windows Server 2012 R2 Datacenter

        .NOTES
            NAME         :  Get-SystemCitrixInfo
            VERSION      :  1.0.1
            LAST UPDATED :  01/18/2018 - Converted all variables to $Private:, since this script is often dot-sourced from $Profile.
                                         Scoping variables as Private ensures they're only used within this script, and not cluttering up Global Variables
            AUTHOR       :  Bryan Dady
    #>
    [CmdletBinding()]
    Param ()

    $Private:hostOSName    = 'Unknown'
    $Private:hostOSCaption = 'Unknown'
    $HostInfo              = Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -Property Caption,CSName,LastBootUpTime
    $hostOSName            = $HostInfo.CSName
    $hostOSCaption         = $HostInfo.Caption -replace 'Microsoft ', ''

    # These should be handled in $PROFILE, but better safe than sorry
    if (-not (Get-Variable -Name onServer -scope Global)) { $Global:onServer = $false }
    if (-not (Get-Variable -Name OnXAHost -scope Global)) { $Global:OnXAHost = $false }
    
    if ($hostOSCaption -like 'Windows Server*') { $Global:onServer = $true }

    if ((-not (Get-Variable -Name CitrixVersion -ErrorAction SilentlyContinue)) -OR ($NULL -ne $CitrixVersion)) {
        Write-Verbose -Message ('$CitrixVersion is {0}' -f $CitrixVersion)
    }

    if ($Global:onServer) {
        # Check for server based Citrix XenApp package and version
        Write-Verbose -Message 'Detecting Citrix Server and version'
        
        $ErrorActionPreference = 'SilentlyContinue'
        #Get-ChildItem -LiteralPath HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall | ForEach-Object -Process {Get-ItemProperty -Path $($PSItem.Name.Replace('HKEY_LOCAL_MACHINE','HKLM:')) | Where-Object -FilterScript {$PSItem.DisplayName -like "*Citrix*" } } | Select-Object -Property DisplayName,DisplayVersion
        $Local:XenApp = Get-ChildItem -LiteralPath HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall | ForEach-Object -Process {Get-ItemProperty -Path $($PSItem.Name.Replace('HKEY_LOCAL_MACHINE\','HKLM:\')) | Where-Object -FilterScript {$PSItem.DisplayName -like 'Citrix*Virtual Delivery Agent*'} | Select-Object -Property DisplayName,DisplayVersion}
        $ErrorActionPreference = 'Continue'
        Write-Verbose -Message ('$Local:XenApp): {0}' -f [bool]$Local:XenApp)
        if ($Local:XenApp) {
            $Local:CitrixName    = $Local:XenApp.DisplayName
            $Local:CitrixVersion = $Local:XenApp.DisplayVersion
            $Global:OnXAHost = $True
            Write-Verbose -Message ('Confirmed Citrix Server {0} is installed.' -f $Local:CitrixName)
            Write-Verbose -Message ('Confirmed Citrix Server version. $Global:OnXAHost: {0}' -f $Global:OnXAHost)
        } else {
            $Local:CitrixName    = 'N/A'
            $Local:CitrixVersion = 'N/A'
            Write-Verbose -Message 'Citrix Server NOT detected.'
        }            
    } else {
        # Detect client/local Citrix Receiver version via registry check
        Write-Verbose -Message 'Detecting Citrix Receiver version'
        $ErrorActionPreference = 'SilentlyContinue'
        $Local:Receiver = Get-ChildItem -LiteralPath HKCU:\Software\Citrix\Receiver\InstallDetect | ForEach-Object -Process {Get-ItemProperty -Path $($PSItem.Name.Replace('HKEY_CURRENT_USER\','HKCU:\')) | Where-Object -FilterScript {$PSItem.DisplayName -like 'Citrix Receiver*'} | Select-Object -Property DisplayName,DisplayVersion}
        $Local:Receiver = $Local:Receiver | Sort-Object -Property DisplayVersion -Descending -Unique

        #HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\CitrixOnlinePluginPackWeb
        # DisplayName example: 'Citrix Receiver 4.9 LTSR'
        $ErrorActionPreference = 'Continue'
        try {
            $Local:CitrixName    = $Local:Receiver.DisplayName
            $Local:CitrixVersion = $Local:Receiver.DisplayVersion
            Write-Verbose -Message 'Confirmed Citrix Receiver is installed :'
            Write-Verbose -Message $Local:Receiver | Format-List
            Write-Verbose -Message 'Confirmed Citrix Receiver is installed.'
        }
        catch {
            $Local:CitrixName    = 'N/A'
            $Local:CitrixVersion = 'N/A'
            Write-Verbose -Message 'Citrix Server NOT installed.'
        }            
    }

    #'Optimize New-Object invocation, based on Don Jones' recommendation: https://technet.microsoft.com/en-us/magazine/hh750381.aspx
    $Private:properties  = [ordered]@{
        'DisplayName'    = $Local:CitrixName
        'DisplayVersion' = $Local:CitrixVersion
        'SystemName'     = $Local:hostOSName
        'SystemType'     = $Local:hostOSCaption
    }
    <#
        More Win32_OperatingSystem Properties
        Status                                    : OK
        Name                                      : Microsoft Windows Server 2012 R2 Datacenter | C:\Windows | \Device\Harddisk2\Partition2
        FreePhysicalMemory                        : 22671884
        FreeSpaceInPagingFiles                    : 2224252
        FreeVirtualMemory                         : 23567524
        Caption                                   : Microsoft Windows Server 2012 R2 Datacenter
        Description                               :
        InstallDate                               : 4/7/2017 7:52:49 AM
        CSName                                    : GBCI02CXC004
        CurrentTimeZone                           : -360
        LastBootUpTime                            : 7/28/2017 1:31:29 AM
        LocalDateTime                             : 7/28/2017 3:25:32 PM
        NumberOfLicensedUsers                     :
        NumberOfProcesses                         : 243
        NumberOfUsers                             : 11
        OSType                                    : 18
        SizeStoredInPagingFiles                   : 4096000
        TotalSwapSpaceSize                        :
        TotalVirtualMemorySize                    : 37649792
        TotalVisibleMemorySize                    : 33553792
        Version                                   : 6.3.9600
        DataExecutionPrevention_32BitApplications : True
        DataExecutionPrevention_Available         : True
        DataExecutionPrevention_Drivers           : True
        DataExecutionPrevention_SupportPolicy     : 3
        EncryptionLevel                           : 256
        Organization                              : GBCI
        OSArchitecture                            : 64-bit
        OSLanguage                                : 1033
        RegisteredUser                            : GBCI User
        SerialNumber                              : 00253-50000-00000-AA442
        ServicePackMajorVersion                   : 0
        ServicePackMinorVersion                   : 0
    #>
    $SystemCitrixInfo = New-Object -TypeName PSObject -Property $Private:properties
    return $SystemCitrixInfo
}

Write-Verbose -Message 'Declaring function Start-XenApp'
function Start-XenApp {
    <#
        .SYNOPSIS
            Extension of Sperry module, to simplify invoking Citrix Receiver PNAgent.exe
        .DESCRIPTION
            Sets pnagent path string, assigns frequently used arguments to function parameters, including aliases to known /Qlaunch arguments
        .PARAMETER Qlaunch
            The Qlaunch parameter references a shortcut name, to be referenced against the known XenApp apps to launch, and then passes to pnagent to be launched by Citrix
        .PARAMETER Reconnect
            Requests that PNAgent attempt to reconnect to any existing Citrix XenApp session for the current user
        .PARAMETER Terminatewait
            Attempts to close all applications in the current user's Citrix XenApp session, and logoff from that session
        .PARAMETER ListAvailable
            Enumerates available XenApp shortcuts that can be passed to -QLaunch

        .EXAMPLE
            PS C:\> Start-XenApp -Qlaunch rdp
            Remote Desktop (or mstsc.exe) client, using the rdp alias, which is defined in the $XenApps hashtable
        .EXAMPLE
            PS C:\> Start-XenApp -open excel
            Open Excel, using the -open alias for the -Qlaunch parameter
        .EXAMPLE
            PS C:\> Start-XenApp -ListAvailable
            Enumerate available XenApp shortcuts to launch
        .NOTES
            NAME        :  Start-XenApp
            VERSION     :  1.3
            LAST UPDATED:  4/9/2015
            AUTHOR      :  Bryan Dady
    #>
    [CmdletBinding()]
    Param (
        [Parameter(
            Position = 0,
            ParameterSetName = 'Mode'
		)]
        [Alias('args','XenApp','qlaunch','start','open')]
        [String]
        $Launch,
        [Parameter(
            Position = 3,
            ParameterSetName = 'Launch'
		)]
        [ValidateNotNullOrEmpty()]
        [Alias('connect')]
        [switch]
        $Reconnect,
        [Parameter(
            Position = 1,
            ParameterSetName = 'Mode'
		)]
        [ValidateNotNullOrEmpty()]
        [Alias('end', 'close', 'halt', 'exit', 'stop')]
        [switch]
        $Terminate,

        [Parameter(
            Position = 2,
            ParameterSetName = 'Mode'
		)]
        [ValidateNotNullOrEmpty()]
        [Alias('list', 'show', 'enumerate')]
        [switch]
        $ListAvailable

    )
    Show-Progress -msgAction Start -msgSource $PSCmdlet.MyInvocation.MyCommand.Name

    Write-Debug -Message ('$PSBoundParameters: {0}' -f $PSBoundParameters)
    #Write-Debug -Message $PSBoundParameters
    Write-Debug -Message ('$PSBoundParameters.Keys: {0}' -f $PSBoundParameters.Keys)
    #Write-Debug -Message $PSBoundParameters.Keys
    Write-Debug -Message ('$PSBoundParameters.Values: {0}' -f $PSBoundParameters.Values)
    #Write-Debug -Message $PSBoundParameters.Values

    if ((-not (Get-Variable -Name CitrixVersion -ErrorAction SilentlyContinue)) -OR ($NULL -ne $CitrixVersion)) {
        Write-Verbose -Message ('$CitrixVersion is {0}' -f $CitrixVersion)
    } else {
        Write-Verbose -Message 'Getting System and Citrix info (Get-SystemCitrixInfo)'
        $Local:SystemCitrixInfo = Get-SystemCitrixInfo
        $CitrixName             = $Local:SystemCitrixInfo.DisplayName
        $CitrixVersion          = $Local:SystemCitrixInfo.DisplayVersion
    }

    # Default GoForLaunch is false; switched to $true only if/when Citrix Receiver is available, and a valid app to Launch is confirmed.
    $Private:GoForLaunch = $false
    $Private:XenApps = @{}

    if ($Global:OnXAHost) {
        Write-Warning -Message "Start-XenApp is designed to run from Citrix Receiver client, not from the session server.`n`tExiting."
    } else {
        if ($CitrixVersion -lt 4.2) {
            # Set XenApp 6 edition PNAgent ICA client
            Write-Verbose -Message 'Setting $ICAclient to pnagent.exe'
            $ICAClient = "${env:ProgramFiles(x86)}\Citrix\ICA Client\pnagent.exe"
            
            if ('Verbose' -in $PSBoundParameters.Keys) {
                Write-Verbose -Message 'Output Level is [Verbose]. $Global:MySettings:'
                Get-Variable -Name MySettings -Scope Global | Select-Object -ExpandProperty Value
                '$Private:XenApps'
                $Private:XenApps
            }

            #  Load up $Setting.XenApp from Sperry module into Script scope $XenApps hashtable
            if ($Global:MySettings.XenApp) {
                Write-Verbose -Message 'Reading available XenApp definitions from $MySettings'
                $Global:MySettings.XenApp | ForEach-Object {
                    Write-Verbose -Message ('{0} = {1}' -f $PSItem.Name, $ExecutionContext.InvokeCommand.ExpandString($PSItem.Qlaunch))
                    Write-Debug -Message ('{0} = {1}' -f $PSItem.Name, $ExecutionContext.InvokeCommand.ExpandString($PSItem.Qlaunch))
                    $Private:XenApps.Add("$($PSItem.Name)",$ExecutionContext.InvokeCommand.ExpandString($PSItem.Qlaunch))
                }
            } else {
                Write-Output -InputObject ''
                throw 'Unable to load global settings from $MySettings object. Perhaps there was an error loading from the Sperry module.'
                Write-Output -InputObject ''
            }
        } else {
            # Make StoreFront / SelfService default ICA client
            Write-Verbose -Message 'Setting $ICAClient to SelfService.exe'
            $ICAClient = "${env:ProgramFiles(x86)}\Citrix\ICA Client\SelfServicePlugin\SelfService.exe"
            # Pull available Citrix apps details from local registry
            Write-Verbose -Message 'Reading available XenApp definitions from registry'
            Get-ChildItem -LiteralPath HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall | Where-Object -FilterScript {$PSItem.Name -like '*glacier*'} | `
            ForEach-Object -Process {$Private:XenApps.Add($($PSItem.GetValue('DisplayName')),$($PSItem.GetValue('LaunchString')))}
        }
    }

    if (-not ($Global:OnXAHost)) {
        # Process arguments
        $Private:Arguments = ''
        if ($Private:XenApps.Keys -contains $Launch) {
            Write-Verbose -Message ('Matched $Launch ({0}) in $XenApps.Keys' -f $Launch)
            if ($CitrixVersion -lt 4.2) {
                #$Private:Arguments = '/CitrixShortcut: (1)', "/QLaunch ""$($Private:XenApps.$Launch)"""
                $Private:Arguments = ('/CitrixShortcut: (1) /QLaunch "{0}"' -f $Private:XenApps.$Launch)
            } else {
                #$Private:Arguments = "-qlaunch ""$Launch"""
                $Private:Arguments = ('-qlaunch "{0}"' -f $Launch)
            }
        } elseif ($Launch.Length -ge 2) {
            # if a shortcut key is not defined in $XenApps, pass the full 'string' e.g. GBCI02XA:Internet Explorer
            Write-Verbose -Message ('Attempting to Launch ({0})' -f $Launch)
            if ($CitrixVersion -lt 4.2) {
                #$Private:Arguments = '/CitrixShortcut: (1)', '/QLaunch', """GBCI02XA:$Launch"""
                $Private:Arguments = ('/CitrixShortcut: (1) /QLaunch "GBCI02XA:{0}"' -f $Launch)
            } else {
                #$Private:Arguments = "-qlaunch ""$Launch"""
                $Private:Arguments = ('-qlaunch "{0}"' -f $Launch)
            }
        }
        # For SelfService.exe // These parameters are available only in Receiver 4.2 and later versions.
        # https://support.citrix.com/article/CTX200337
        <#
            SelfService.exe -rmPrograms
            Clean up shortcuts and stub programs for current user.

            SelfService.exe -reconnectapps
            Reconnect to any existing sessions the user has. By default happens at launch time and app refresh time.

            SelfService.exe -poll  Contact the server to refresh application details. 
            SelfService.exe -ipoll  Contact the server to refresh application details as in -poll, but if no authentication context is available, prompt the user for credentials. 

            SelfService.exe -exit Exit from SelfService.exe. 
            SelfService.exe -qlaunch "appname" See Note 1. 
            Launch applications.
                Note: This parameter can be customized with <appname> <argument>. Publish the application with "%*" in command line parameter.   Example: To launch published application named "IE11" opening http://www.citrix.com, use:
            selfservice.exe -qlaunch IE11 http://www.citrix.com

            SelfService.exe -qlogon
            Reconnect any existing apps for current user.

            SelfService.exe -terminateuser "user_name"
            Disconnect applications for a specific user.

            # ============================================
            # For PNAgent.exe
            # /Terminate Closes out PNAgent and any open sessions
            # /terminatewait  Closes out PNAgent and any open sessions; Logs off
            # /Configurl  /param:URL  (useful if you haven't set up the client as part of the install)
            # /displaychangeserver
            # /displayoptions
            # /logoff
            # /refresh
            # /disconnect
            # /reconnect
            # /reconnectwithparam
            # /qlaunch  (syntax example pnagent.exe /Qlaunch "Farm1:Calc")
        #>
    }

    if (-not ($Global:OnXAHost)) {
        if ($PSBoundParameters.ContainsKey('Reconnect')) {
            Write-Verbose -Message '($PSBoundParameters.ContainsKey(''Reconnect''))'
            Write-Verbose -Message ($PSBoundParameters.ContainsKey('Reconnect'))
            if ($CitrixVersion -lt 4.2 ) {
                Write-Log -Message 'Start pnagent.exe /reconnect' -Function $PSCmdlet.MyInvocation.MyCommand.Name
                Start-Process -FilePath $ICAClient -ArgumentList '/reconnect' -PassThru
            } else {
                Write-Log -Message 'Start SelfService.exe -reconnectapps' -Function $PSCmdlet.MyInvocation.MyCommand.Name
                Start-Process -FilePath $ICAClient -ArgumentList '-reconnectapps' -PassThru
            }
        } elseif ($PSBoundParameters.ContainsKey('Terminate')) {
            Write-Verbose -Message '($PSBoundParameters.ContainsKey(''Terminate''))'
            Write-Verbose -Message ($PSBoundParameters.ContainsKey('Terminate'))
            if ($CitrixVersion -lt 4.2 ) {
                Write-Log -Message 'Start pnagent.exe /TerminateWait' -Function $PSCmdlet.MyInvocation.MyCommand.Name
                Start-Process -FilePath $ICAClient -ArgumentList '/terminatewait' -PassThru
            } else {
                Write-Log -Message 'Start SelfService.exe -Terminate' -Function $PSCmdlet.MyInvocation.MyCommand.Name
                Start-Process -FilePath $ICAClient -ArgumentList '-terminate' -PassThru
            }
        } elseif ($PSBoundParameters.ContainsKey('ListAvailable')) {
            Write-Log -Message 'Enumerating available $XenApps (for -Launch)' -Function $PSCmdlet.MyInvocation.MyCommand.Name -Verbose
            $Private:XenApps.Keys | Sort-Object # -Property Name | Format-Table -AutoSize
        } else {
            $Private:GoForLaunch = $true
        }
        Write-Verbose -Message ('Finalized $Private:Arguments is: {0}' -f  $Private:Arguments)
    }

    # As long as we have non-0 arguments, run it using Start-Process and arguments list
    if ($Private:GoForLaunch) {
        if ($Private:Arguments -ne $NULL) {
            #$Message = "Starting $($Arguments.Replace('/CitrixShortcut: (1) /QLaunch ',''))"
            $Message = ('Starting {0} {1}' -f $ICAClient, $Arguments.Replace('/CitrixShortcut: (1) /QLaunch ',''))
            $Message = ('Starting {0} {1}' -f $ICAClient, $Arguments.Replace('-qlaunch ',''))
            #$Message = "Starting $($Arguments.Replace('-qlaunch ',''))"
            Write-Log -Message $Message -Function $PSCmdlet.MyInvocation.MyCommand.Name -Verbose
            Start-Process -FilePath $ICAClient -ArgumentList "$Private:Arguments"
        } else {
            Write-Log -Message "Unrecognized XenApp shortcut: $XenApp`n`tPlease try again with one of the following:" -Function $PSCmdlet.MyInvocation.MyCommand.Name -Verbose
            Write-Debug -Message $Private:XenApps.Keys
            $Private:XenApps.Keys # | Sort-Object -Property Name | Format-Table -AutoSize
            break
        }
    }
    Show-Progress -msgAction Stop -msgSource $PSCmdlet.MyInvocation.MyCommand.Name
}
