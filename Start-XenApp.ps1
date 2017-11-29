#Requires -Version 2
# Enhanced May 2017 to support XenApp 7 and StoreFront
[cmdletbinding()]
Param()

Write-Verbose -Message 'Declaring function Start-CitrixSession'
function Start-CitrixSession {
    [CmdletBinding()]
    param ()
    Show-Progress -msgAction 'Start' -msgSource $MyInvocation.MyCommand.Name # Log start time stamp

    if (-not (Get-Variable -Name onServer -Scope Global -ErrorAction SilentlyContinue)) {
        $Global:onServer = $false
        if ((Get-WmiObject -Class Win32_OperatingSystem -Property Caption).Caption -like '*Windows Server*') {
            $Global:onServer = $true
        }
    }

    # if (-not (Test-LocalAdmin)) {
        if ((-not (Get-Process -Name Receiver -ErrorAction SilentlyContinue)) -and (-not $Global:onServer)) {
            # Write-Log -Message 'Need to elevate privileges for proper completion ... requesting admin credentials.' -Function $MyInvocation.MyCommand.Name
            # Start-Sleep -Milliseconds 333
            # # Before we launch an elevated process, check (via function) that UAC is conveniently set
            # Open-UAC
            # Open-AdminConsole -Command {Start-CitrixSession} 
            # Look for Receiver shortcut in registry
            if (Test-Path -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\*Citrix Receiver.lnk") {
                "Starting Citrix Receiver: ($((Resolve-Path -Path ""$env:ProgramData\Microsoft\Windows\Start Menu\Programs\*Citrix Receiver.lnk"").Path))"
                & (Resolve-Path -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\*Citrix Receiver.lnk").Path
                " ... "
                Start-Sleep -Seconds 3
            }
        } else {
            Write-Log -Message 'Confirmed Citrix Receiver is running.' -Function $MyInvocation.MyCommand.Name
        }
    #}

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
        Write-Output -InputObject " # Default Printer # : $((Get-Printer -Default | Select-Object -Property ShareName).ShareName)"
    } else {
        Write-Verbose -Message "`$thisHour: $thisHour"
        Write-Verbose -Message "`$Global:onServer : $Global:onServer"
        Write-Verbose -Message "Get-ProcessByUser -ProcessName 'outlook.exe': $([bool](Get-ProcessByUser -ProcessName 'outlook.exe' -ErrorAction Ignore))"
    #    Write-Verbose -Message "Get-ProcessByUser -ProcessName 'VDARedirector.exe': $([bool](Get-ProcessByUser -ProcessName 'VDARedirector.exe' -ErrorAction Ignore))"
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
            VERSION      :  0.1.0
            LAST UPDATED :  7/28/2017
            AUTHOR       :  Bryan Dady
    #>
    [CmdletBinding()]
    Param ()

    $Script:HostInfo = Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -Property Caption,CSName,LastBootUpTime
    $script:hostOSCaption = $($Script:HostInfo).Caption -replace 'Microsoft ', ''

    # This might be handled in $PROFILE, but better safe than sorry
    $Global:onServer = $false
    $Global:OnXAHost = $false

    if ($script:hostOSCaption -like 'Windows Server*') {
        $Global:onServer = $true
    }

    if (Get-Variable -Name CitrixVersion -Scope Global -ErrorAction SilentlyContinue) {
        Write-Verbose -Message "`$Global:CitrixVer previously set to $Global:CitrixVersion"
    }

    if ($Global:onServer) {
        # Check for server based Citrix XenApp package and version
        Write-Verbose -Message 'Detecting Citrix Server and version'
        
        $ErrorActionPreference = 'SilentlyContinue'
        #Get-ChildItem -LiteralPath HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall | ForEach-Object -Process {Get-ItemProperty -Path $($PSItem.Name.Replace('HKEY_LOCAL_MACHINE','HKLM:')) | Where-Object -FilterScript {$PSItem.DisplayName -like "*Citrix*" } } | Select-Object -Property DisplayName,DisplayVersion
        $Script:XenApp = Get-ChildItem -LiteralPath HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall | ForEach-Object -Process {Get-ItemProperty -Path $($PSItem.Name.Replace('HKEY_LOCAL_MACHINE\','HKLM:\')) | Where-Object -FilterScript {$PSItem.DisplayName -like "Citrix*Virtual Delivery Agent*"} | Select-Object -Property DisplayName,DisplayVersion}
        $ErrorActionPreference = 'Continue'
        Write-Verbose -Message "(`$Script:XenApp): [bool]($Script:XenApp)"
        if ($Script:XenApp) {
            $Script:CitrixName    = $Script:XenApp.DisplayName
            $Script:CitrixVersion = $Script:XenApp.DisplayVersion
            $Global:OnXAHost = $True
            Write-Verbose -Message "Confirmed Citrix Server $Script:CitrixName is installed."
            Write-Verbose -Message "Confirmed Citrix Server version.`n `$Global:OnXAHost = $Global:OnXAHost"
        } else {
            $Script:CitrixName    = 'N/A'
            $Script:CitrixVersion = 'N/A'
            Write-Verbose -Message "Citrix Server NOT detected."
        }            
    } else {
        # Detect client/local Citrix Receiver version via registry check
        Write-Verbose -Message 'Detecting Citrix Receiver version'
        $ErrorActionPreference = 'SilentlyContinue'
        $Script:Receiver = Get-ChildItem -LiteralPath HKCU:\Software\Citrix\Receiver\InstallDetect | ForEach-Object -Process {Get-ItemProperty -Path $($PSItem.Name.Replace('HKEY_CURRENT_USER\','HKCU:\')) | Where-Object -FilterScript {$PSItem.DisplayName -like "Citrix Receiver*"} | Select-Object -Property DisplayName,DisplayVersion}
        $ErrorActionPreference = 'Continue'
        try {
            $Script:CitrixName    = $Script:Receiver.DisplayName
            $Script:CitrixVersion = $Script:Receiver.DisplayVersion
            Write-Verbose -Message 'Confirmed Citrix Receiver is installed :'
            Write-Verbose -Message $Receiver | Format-List
            Write-Verbose -Message "Confirmed Citrix Receiver is installed."
        }
        catch {
            $Script:CitrixName    = 'N/A'
            $Script:CitrixVersion = 'N/A'
            Write-Verbose -Message "Citrix Server NOT installed."
        }            
    }

    #'Optimize New-Object invocation, based on Don Jones' recommendation: https://technet.microsoft.com/en-us/magazine/hh750381.aspx
    $Private:properties = [ordered]@{
        'DisplayName'    = $Script:CitrixName
        'DisplayVersion' = $Script:CitrixVersion
        'SystemName'     = $Script:HostInfo.CSName
        'SystemType'     = $script:hostOSCaption
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
    $SystemCitrixInfo = New-Object -TypeName PSObject -Prop $Private:properties
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

    Write-Debug -Message '$PSBoundParameters:'
    Write-Debug -Message $PSBoundParameters
    Write-Debug -Message '$PSBoundParameters.Keys:'
    Write-Debug -Message $PSBoundParameters.Keys
    Write-Debug -Message '$PSBoundParameters.Values:'
    Write-Debug -Message $PSBoundParameters.Values

    if (Get-Variable -Name CitrixVer -Scope Global -ErrorAction SilentlyContinue) {
        Write-Verbose -Message "`$CitrixVer already set to $Global:CitrixVer"
    } else {
        Write-Verbose -Message "Getting System and Citrix info (Get-SystemCitrixInfo)"
        $Script:SystemCitrixInfo = Get-SystemCitrixInfo
        $Global:CitrixName = $Script:SystemCitrixInfo.DisplayName
        $Global:CitrixVer  = $Script:SystemCitrixInfo.DisplayVersion
    }

    # Default GoForLaunch is false; switched to $true only if/when Citrix Receiver is available, and a valid app to Launch is confirmed.
    $Script:GoForLaunch = $false
    $Script:XenApps = @{}

    if ($Global:OnXAHost) {
        Write-Warning -Message "Start-XenApp is designed to run from Citrix Receiver client, not from the session server.`n`tExiting."
    } else {
        if ($Global:CitrixVer -lt 4.2) {
            # Set XenApp 6 edition PNAgent ICA client
            Write-Verbose -Message 'Setting $ICAclient to pnagent.exe'
            Global:ICAClient = "${env:ProgramFiles(x86)}\Citrix\ICA Client\pnagent.exe"
            #  Load up $Setting.XenApp from sperry.json into Script scope $XenApps hashtable

            if (($Script:XenApps -eq 0) -and ([bool]$($Settings.XenApp))) {
                Write-Verbose -Message 'Reading available XenApp definitions from $Settings'
                $Settings.XenApp | ForEach-Object {
                    Write-Verbose -Message "$($PSItem.Name) = $($ExecutionContext.InvokeCommand.ExpandString($PSItem.Qlaunch))"
                    Write-Debug -Message "$($PSItem.Name) = $($ExecutionContext.InvokeCommand.ExpandString($PSItem.Qlaunch))"
                    $script:XenApps.Add("$($PSItem.Name)",$ExecutionContext.InvokeCommand.ExpandString($PSItem.Qlaunch))
                }
            } else {
                throw "Unable to load global settings from `$Settings object. Perhaps there was an error loading from sperry.json."
            }
        } else {
            # Make StoreFront / SelfService default ICA client
            Write-Verbose -Message 'Setting $ICAClient to SelfService.exe'
            $Global:ICAClient = "${env:ProgramFiles(x86)}\Citrix\ICA Client\SelfServicePlugin\SelfService.exe"
            # Pull available Citrix apps details from local registry
            Write-Verbose -Message 'Reading available XenApp definitions from registry'
            Get-ChildItem -LiteralPath HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall | Where-Object -FilterScript {$PSItem.Name -like "*glacier*"} | `
            ForEach-Object -Process {$script:XenApps.Add($($PSItem.GetValue('DisplayName')),$($PSItem.GetValue('LaunchString')))}
        }
    }

    if (-not ($Global:OnXAHost)) {
        # Process arguments
        $Private:Arguments = ''
        if ($Script:XenApps.Keys -contains $Launch) {
            Write-Verbose -Message "Matched `$Launch ('$Launch') in `$XenApps.Keys"
            if ($Global:CitrixVer -lt 4.2) {
                $Private:Arguments = '/CitrixShortcut: (1)', "/QLaunch ""$($Script:XenApps.$Launch)"""
            } else {
                $Private:Arguments = "-qlaunch ""$Launch"""
            }
        } elseif ($Launch.Length -ge 2) {
            # if a shortcut key is not defined in $XenApps, pass the full 'string' e.g. GBCI02XA:Internet Explorer
            Write-Verbose -Message "Attempting to Launch ('$Launch')"
            if ($Global:CitrixVer -lt 4.2) {
                $Private:Arguments = '/CitrixShortcut: (1)', '/QLaunch', """GBCI02XA:$Launch"""
                # possible RFE: enhance string whitespace handling of $Launch
            } else {
                $Private:Arguments = "-qlaunch ""$Launch"""
            }
        }
        # For SelfService.exe // These parameters are available only in Receiver 4.2 and later versions.
        # https://support.citrix.com/article/CTX200337
        <#
            SelfService.exe –rmPrograms
            Clean up shortcuts and stub programs for current user.

            SelfService.exe –reconnectapps
            Reconnect to any existing sessions the user has. By default happens at launch time and app refresh time.

            SelfService.exe –poll  Contact the server to refresh application details. 
            SelfService.exe –ipoll  Contact the server to refresh application details as in –poll, but if no authentication context is available, prompt the user for credentials. 

            SelfService.exe –exit Exit from SelfService.exe. 
            SelfService.exe –qlaunch “appname” See Note 1. 
            Launch applications.
                Note: This parameter can be customized with <appname> <argument>. Publish the application with “%*” in command line parameter.   Example: To launch published application named "IE11" opening http://www.citrix.com, use:
            selfservice.exe -qlaunch IE11 http://www.citrix.com

            SelfService.exe –qlogon
            Reconnect any existing apps for current user.

            SelfService.exe –terminateuser “user_name”
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
            if ($Global:CitrixVer -lt 4.2 ) {
                Write-Log -Message 'Start pnagent.exe /reconnect' -Function $PSCmdlet.MyInvocation.MyCommand.Name
                Start-Process $Global:ICAClient -ArgumentList '/reconnect' -PassThru
            } else {
                Write-Log -Message 'Start SelfService.exe –reconnectapps' -Function $PSCmdlet.MyInvocation.MyCommand.Name
                Start-Process $Global:ICAClient -ArgumentList '–reconnectapps' -PassThru
            }
        } elseif ($PSBoundParameters.ContainsKey('Terminate')) {
            Write-Verbose -Message '($PSBoundParameters.ContainsKey(''Terminate''))'
            Write-Verbose -Message ($PSBoundParameters.ContainsKey('Terminate'))
            if ($Global:CitrixVer -lt 4.2 ) {
                Write-Log -Message 'Start pnagent.exe /TerminateWait' -Function $PSCmdlet.MyInvocation.MyCommand.Name
                Start-Process $Global:ICAClient -ArgumentList '/terminatewait' -PassThru
            } else {
                Write-Log -Message 'Start SelfService.exe -Terminate' -Function $PSCmdlet.MyInvocation.MyCommand.Name
                Start-Process $Global:ICAClient -ArgumentList '-terminate' -PassThru
            }
        } elseif ($PSBoundParameters.ContainsKey('ListAvailable')) {
            Write-Log -Message '`nEnumerating all available `$XenApps Keys' -Function $PSCmdlet.MyInvocation.MyCommand.Name -Verbose
            $Script:XenApps.Keys | Sort-Object # -Property Name | Format-Table -AutoSize
        } else {
            $Script:GoForLaunch = $true
        }
        write-Debug -Message "At the end, `$Private:Arguments is $Private:Arguments"
    }

    # As long as we have non-0 arguments, run it using Start-Process and arguments list
    if ($Script:GoForLaunch) {
        if ($Private:Arguments -ne $NULL) {
            $Message = "Starting $($Arguments.Replace('/CitrixShortcut: (1) /QLaunch ',''))"
            $Message = "Starting $($Arguments.Replace('-qlaunch ',''))"
            Write-Log -Message $Message -Function $PSCmdlet.MyInvocation.MyCommand.Name -Verbose
            Start-Process $Global:ICAClient -ArgumentList "$Private:Arguments" -Verbose
        } else {
            Write-Log -Message "Unrecognized XenApp shortcut: $XenApp`n`tPlease try again with one of the following:" -Function $PSCmdlet.MyInvocation.MyCommand.Name -Verbose
            Write-Debug -Message $Script:XenApps.Keys
            $Script:XenApps.Keys # | Sort-Object -Property Name | Format-Table -AutoSize
            break
        }
    }
    Show-Progress -msgAction Stop -msgSource $PSCmdlet.MyInvocation.MyCommand.Name
}
