#Requires -Version 3
# -Module CimCmdlets, PSLogger, Sperry
# Enhanced May 2017 to support XenApp 7 and StoreFront
[cmdletbinding()]
Param()

# Uncomment the following 2 lines for testing profile scripts with Verbose output
#'$VerbosePreference = ''Continue'''
#$VerbosePreference = 'Continue'

Write-Verbose -Message 'Detect -Verbose $VerbosePreference'
switch ($VerbosePreference) {
    Stop             { $IsVerbose = $True }
    Inquire          { $IsVerbose = $True }
    Continue         { $IsVerbose = $True }
    SilentlyContinue { $IsVerbose = $False }
    Default          { if ('Verbose' -in $PSBoundParameters.Keys) {$IsVerbose = $True} else {$IsVerbose = $False} }
}
Write-Verbose -Message ('$VerbosePreference = ''{0}'' : $IsVerbose = ''{1}''' -f $VerbosePreference, $IsVerbose)

#Region MyScriptInfo
    Write-Verbose -Message ('[{0}] Populating $MyScriptInfo' -f $MyInvocation.MyCommand.Name)
    $MyCommandName        = $MyInvocation.MyCommand.Name
    $MyCommandPath        = $MyInvocation.MyCommand.Path
    $MyCommandType        = $MyInvocation.MyCommand.CommandType
    $MyCommandModule      = $MyInvocation.MyCommand.Module
    $MyModuleName         = $MyInvocation.MyCommand.ModuleName
    $MyCommandParameters  = $MyInvocation.MyCommand.Parameters
    $MyParameterSets      = $MyInvocation.MyCommand.ParameterSets
    $MyRemotingCapability = $MyInvocation.MyCommand.RemotingCapability
    $MyVisibility         = $MyInvocation.MyCommand.Visibility

    if (($null -eq $MyCommandName) -or ($null -eq $MyCommandPath)) {
        # We didn't get a successful command / script name or path from $MyInvocation, so check with CallStack
        Write-Verbose -Message 'Getting PSCallStack [$CallStack = Get-PSCallStack]'
        $CallStack      = Get-PSCallStack | Select-Object -First 1
        # $CallStack | Select Position, ScriptName, Command | format-list # FunctionName, ScriptLineNumber, Arguments, Location
        $myScriptName   = $CallStack.ScriptName
        $myCommand      = $CallStack.Command
        Write-Verbose -Message ('$ScriptName: {0}' -f $myScriptName)
        Write-Verbose -Message ('$Command: {0}' -f $myCommand)
        Write-Verbose -Message 'Assigning previously null MyCommand variables with CallStack values'
        $MyCommandPath  = $myScriptName
        $MyCommandName  = $myCommand
    }

    #'Optimize New-Object invocation, based on Don Jones' recommendation: https://technet.microsoft.com/en-us/magazine/hh750381.aspx
    $properties = [ordered]@{
        'CommandName'        = $MyCommandName
        'CommandPath'        = $MyCommandPath
        'CommandType'        = $MyCommandType
        'CommandModule'      = $MyCommandModule
        'ModuleName'         = $MyModuleName
        'CommandParameters'  = $MyCommandParameters.Keys
        'ParameterSets'      = $MyParameterSets
        'RemotingCapability' = $MyRemotingCapability
        'Visibility'         = $MyVisibility
    }
    $MyScriptInfo = New-Object -TypeName PSObject -Property $properties
    Write-Verbose -Message ('[{0}] $MyScriptInfo populated' -f $MyInvocation.MyCommand.Name)

    # Cleanup
    foreach ($var in $properties.Keys) {
        Remove-Variable -Name ('My{0}' -f $var) -Force
    }
    Remove-Variable -Name properties
    Remove-Variable -Name var

    if ($IsVerbose) {
        Write-Verbose -Message '$MyScriptInfo:'
        $Script:MyScriptInfo
    }
#End Region

# Define Shared variables at the script root so they can be (re-)used across functions
Set-Variable -Name CitrixName    -Value $NULL -Scope Script -Option AllScope
Set-Variable -Name CitrixVersion -Value $NULL -Scope Script -Option AllScope
Set-Variable -Name ICAClient     -Value $NULL -Scope Script -Option AllScope

Write-Verbose -Message 'Declaring function Start-CitrixSession'
function Start-CitrixSession {
    [CmdletBinding()]
    param ()
    Show-Progress -msgAction 'Start' -msgSource $MyInvocation.MyCommand.Name # Log start time stamp

    if ((-not (Get-Variable -Name IsServer -Scope Global -ErrorAction SilentlyContinue)) -OR ($NULL -ne $IsServer)) {
        $Global:IsServer = $false
        if ($hostOSCaption -like '*Windows Server*') {
            $Global:IsServer = $true
        }
    }

    if ((-not (Get-Process -Name Receiver -ErrorAction SilentlyContinue)) -and (-not $Global:IsServer)) {
        if (Test-Path -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\*Citrix Receiver.lnk") {
            "Starting Citrix Receiver: ($((Resolve-Path -Path ""$env:ProgramData\Microsoft\Windows\Start Menu\Programs\*Citrix Receiver.lnk"").Path))"
            & (Resolve-Path -Path "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\*Citrix Receiver.lnk").Path
            ' ... '
            Start-Sleep -Seconds 3
        } else {

        }
    } else {
        Write-Log -Message 'Confirmed Citrix Receiver is running.' -Function $MyInvocation.MyCommand.Name
    }

    # Check if running on server or in client (Citrix Receiver) context
    if (-not ($Global:IsServer)) {
        # Confirm Citrix XenApp shortcuts are available, and then launch frequently used apps
        if (test-path -Path "$env:USERPROFILE\Desktop\Assyst.lnk" -PathType Leaf) {
            Write-Output -InputObject 'Starting Citrix session (Internet Explorer [on WS2016])'
            Start-XenApp -Qlaunch 'Internet Explorer 2016'
            Write-Output -InputObject 'Pausing for Citrix (XenApp) session to load ...'
            Start-Sleep -Seconds 80
            Write-Output -InputObject 'Starting Skype for Business (2016)'
            Start-XenApp -Qlaunch 'Skype for Business 2016'
            Start-Sleep -Seconds 10
            Write-Output -InputObject 'Starting H Drive (2016)'
            Start-XenApp -Qlaunch 'H Drive 2016'
            Start-Sleep -Seconds 10
        } else {
            Write-Log -Message 'Unable to locate XenApp shortcuts. Please check network connectivity to workplace resources and try again.' -Function $MyInvocation.MyCommand.Name -Verbose
        }
    }

    # Before invoking Start-MyXenApps, look for or create a breadcrumb to keep track of when MyXenApps were last started, so as to avoid re-launching duplicate/redundant application windows
    Write-Verbose -Message 'Checking if work apps should be auto-started'
    $StartNewSession = $false
    $thisHour = (Get-Date -DisplayHint Time).Hour
    if (($thisHour -ge 6) -and ($thisHour -le 18)) {
        # current hour is within business hours
        Write-Verbose -Message ('Current time {0} is within business hours' -f (Get-Date -DisplayHint Time))
        Write-Verbose -Message ('$Global:IsServer: {0}' -f $Global:IsServer)
        if ($Global:IsServer) {
            # Filtering results of Get-Process for those with a non-null Description is easier than my prior WMI approach via Get-ProcessByUser
            $MyProcessList = Get-Process -Name chrome,excel,firefox,outlook,onenote,word -ErrorAction SilentlyContinue | Where-Object -FilterScript {$null -ne $_.Description} | Select-Object -Property ProcessName,Description -Unique

            Write-Verbose -Message ('MyProcessList is null: {0}' -f ($null -eq $MyProcessList))
            Write-Verbose -Message ('MyProcessList is empty: {0}' -f [bool](Select-Object -InputObject $MyProcessList -Property Count))

            If ($null -eq $MyProcessList) {
                $StartNewSession = $true
            } else {
                If (-not (Select-Object -InputObject $MyProcessList -Property Count)) {
                    $StartNewSession = $true
                }
            }
            Write-Verbose -Message ('MyProcessList :: $StartNewSession: {0}' -f $StartNewSession)
        } else {
            # if / when NOT runing in a Server (RDS) environment, presume it's safe to (re-)run Start-MyXenApps
            Write-Verbose -Message ('$StartNewSession: {0}' -f $StartNewSession)
            $StartNewSession = $true
        }
    } else {
        Write-Verbose -Message ('Current time {0} is outside business hours' -f (Get-Date -DisplayHint Time))
    }

    if ($StartNewSession) {
        Write-Verbose -Message 'Starting work apps'
        Write-Output -InputObject ' # Start-MyXenApps #'
        Start-MyXenApps
        Write-Output -InputObject (' # Default Printer: {0} #' -f (Get-Printer -Default | Select-Object -ExpandProperty ShareName))
    }

    Show-Progress -msgAction 'Stop' -msgSource $MyInvocation.MyCommand.Name # Log end time stamp
    return $true # (Get-Process -Name Receiver).Description
}

Write-Verbose -Message 'Declaring function Get-SystemCitrixInfo'
function Get-SystemCitrixInfo {
    [CmdletBinding()]
    Param ()

    $Private:hostOSName    = 'Unknown'
    $Private:hostOSCaption = 'Unknown'
    $HostInfo              = Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -Property Caption,CSName,LastBootUpTime
    $hostOSName            = $HostInfo.CSName
    $hostOSCaption         = $HostInfo.Caption -replace 'Microsoft ', ''

    # These should be handled in $PROFILE, but better safe than sorry
    if (-not (Get-Variable -Name IsServer -scope Global)) {
        $Global:IsServer = $false
        if ($hostOSCaption -like 'Windows Server*') { $Global:IsServer = $true }
    }
    if (-not (Get-Variable -Name IsCitrixServer -Scope Global -ErrorAction SilentlyContinue)) { $Global:IsCitrixServer = $false }

    if ((-not (Get-Variable -Name CitrixVersion -ErrorAction SilentlyContinue)) -OR ($NULL -ne $CitrixVersion)) {
        Write-Verbose -Message ('$CitrixVersion is {0}' -f $CitrixVersion)
    }

    $Local:CitrixName    = 'N/A'
    $Local:CitrixVersion = 'N/A'
    if ($Global:IsServer) {
        # Check for server based Citrix XenApp package and version
        Write-Verbose -Message 'Detecting Citrix Server and version'

        #$ErrorActionPreference = 'SilentlyContinue'
        $Local:XenApp = Get-Process | Where-Object -FilterScript {$_.Product -like '*Citrix*'} -ErrorAction SilentlyContinue | Select-Object -Property Name,Path,Product,ProductVersion | Sort-Object -Property ProductVersion,Name | Select-Object -First 1
        #$ErrorActionPreference = 'Continue'
        Write-Verbose -Message ('$Local:XenApp): {0}' -f [bool]$Local:XenApp)
        if ($null -eq $Local:XenApp) {
            Write-Verbose -Message 'Citrix Server NOT detected.'
        } else {
            $Local:CitrixName    = $Local:XenApp.Product #DisplayName
            $Local:CitrixVersion = $Local:XenApp.ProductVersion  #DisplayVersion
            if ($Local:CitrixName -like '*ICA Host*') {
                $Global:IsCitrixServer = $True
            }
            Write-Verbose -Message ('Confirmed Citrix Server {0} is installed.' -f $Local:CitrixName)
            Write-Verbose -Message ('Confirmed Citrix Server version. $Global:IsCitrixServer: {0}' -f $Global:IsCitrixServer)
        }
    } else {
        # Detect client/local Citrix Receiver version via registry check
        $Local:Receiver = Get-Process -Name Receiver -ErrorAction SilentlyContinue | Where-Object -FilterScript {$null -ne $PSItem.Path} | Select-Object -Property Name,Path,Product,ProductVersion
        if ($null -eq $Local:Receiver) {
            Write-Verbose -Message 'Failed to confirm local Citrix Receiver is running.'
        } else {
            Write-Verbose -Message 'Confirmed Citrix Receiver is installed :'
            Write-Verbose -Message $Local:Receiver | Format-List
            #Write-Verbose -Message 'Collecting Citrix Receiver Version'
            $Local:CitrixName    = $Local:Receiver.Product #DisplayName
            $Local:CitrixVersion = ('{0}.{1}' -f ($Local:Receiver.ProductVersion -as [version]).Major, ($Local:Receiver.ProductVersion -as [version]).Minor)
        }
    }

    #'Optimize New-Object invocation, based on Don Jones' recommendation: https://technet.microsoft.com/en-us/magazine/hh750381.aspx
    $Private:properties  = [ordered]@{
        'DisplayName'    = $Local:CitrixName
        'DisplayVersion' = $Local:CitrixVersion
        'SystemName'     = $Local:hostOSName
        'SystemType'     = $Local:hostOSCaption
    }

    $SystemCitrixInfo = New-Object -TypeName PSObject -Property $Private:properties
    return $SystemCitrixInfo

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

    <# -- Notes --
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
}

Write-Verbose -Message 'Declaring function Start-XenApp'
function Start-XenApp {
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
    Write-Debug -Message ('$PSBoundParameters.Keys: {0}' -f $PSBoundParameters.Keys)
    Write-Debug -Message ('$PSBoundParameters.Values: {0}' -f $PSBoundParameters.Values)

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

    if ($Global:IsCitrixServer) {
        Write-Warning -Message "Start-XenApp is designed to run from Citrix Receiver client, not from the session server.`n`tExiting."
    } else {
        if ($CitrixVersion -lt 4.2) {
            # Set XenApp 6 edition PNAgent ICA client
            Write-Verbose -Message 'Setting $ICA client to pnagent.exe'
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

    if (-not ($Global:IsCitrixServer)) {
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
        <# -- Notes --
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

    if (-not ($Global:IsCitrixServer)) {
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
            Write-Log -Message 'Enumerating available $XenApps (for -Launch)' -Function $PSCmdlet.MyInvocation.MyCommand.Name
            $Private:XenApps.Keys | Sort-Object # -Property Name | Format-Table -AutoSize
        } else {
            $Private:GoForLaunch = $true
        }
        Write-Verbose -Message ('Finalized $Private:Arguments is: {0}' -f  $Private:Arguments)
    }

    # As long as we have non-0 arguments, run it using Start-Process and arguments list
    if ($Private:GoForLaunch) {
        if ($NULL -ne $Private:Arguments) {
            #$Message = "Starting $($Arguments.Replace('/CitrixShortcut: (1) /QLaunch ',''))"
            $Message = ('Starting {0} {1}' -f $ICAClient, $Arguments.Replace('/CitrixShortcut: (1) /QLaunch ',''))
            $Message = ('Starting {0} {1}' -f $ICAClient, $Arguments.Replace('-qlaunch ',''))
            #$Message = "Starting $($Arguments.Replace('-qlaunch ',''))"
            Write-Log -Message $Message -Function $PSCmdlet.MyInvocation.MyCommand.Name
            Start-Process -FilePath $ICAClient -ArgumentList "$Private:Arguments"
        } else {
            Write-Log -Message "Unrecognized XenApp shortcut: $XenApp`n`tPlease try again with one of the following:" -Function $PSCmdlet.MyInvocation.MyCommand.Name -Verbose
            Write-Debug -Message $Private:XenApps.Keys
            $Private:XenApps.Keys # | Sort-Object -Property Name | Format-Table -AutoSize
            break
        }
    }
    Remove-Variable -Name ICAClient -Scope  -ErrorAction SilentlyContinue
    Show-Progress -msgAction Stop -msgSource $PSCmdlet.MyInvocation.MyCommand.Name

    <#
        .SYNOPSIS
            Extension of Sperry module, to simplify invoking Citrix Receiver PNAgent.exe
        .DESCRIPTION
            Sets pnagent path string, assigns frequently used arguments to function parameters, including aliases to known /QLaunch arguments
        .PARAMETER QLaunch
            The QLaunch parameter references a shortcut name, to be referenced against the known XenApp apps to launch, and then passes to pnagent to be launched by Citrix
        .PARAMETER Reconnect
            Requests that PNAgent attempt to reconnect to any existing Citrix XenApp session for the current user
        .PARAMETER Terminatewait
            Attempts to close all applications in the current user's Citrix XenApp session, and logoff from that session
        .PARAMETER ListAvailable
            Enumerates available XenApp shortcuts that can be passed to -QLaunch

        .EXAMPLE
            PS C:\> Start-XenApp -QLaunch rdp
            Remote Desktop (or mstsc.exe) client, using the rdp alias, which is defined in the $XenApps hashtable
        .EXAMPLE
            PS C:\> Start-XenApp -open excel
            Open Excel, using the -open alias for the -QLaunch parameter
        .EXAMPLE
            PS C:\> Start-XenApp -ListAvailable
            Enumerate available XenApp shortcuts to launch
        .NOTES
            NAME        :  Start-XenApp
            VERSION     :  1.3
            LAST UPDATED:  4/9/2015
            AUTHOR      :  Bryan Dady
    #>
}
