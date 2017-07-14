#Requires -Version 2
# Enhanced May 2017 to support XenApp 7 and StoreFront
[cmdletbinding()]
Param()

Write-Verbose -Message 'Declaring function Start-CitrixSession'
function Start-CitrixSession {
  [CmdletBinding()]
  param ()
  Show-Progress -msgAction 'Start' -msgSource $MyInvocation.MyCommand.Name # Log start time stamp

  if (-not (Test-LocalAdmin)) {
    if ( (-not (Get-Process -Name Receiver -ErrorAction SilentlyContinue) -and (-not $onServer)))
    {
      Write-Log -Message 'Need to elevate privileges for proper completion ... requesting admin credentials.' -Function $MyInvocation.MyCommand.Name
      Start-Sleep -Milliseconds 333
      # Before we launch an elevated process, check (via function) that UAC is conveniently set
      Set-UAC
      Open-AdminConsole -Command {Start-CitrixSession} 
    }
    else
    {
      Write-Log -Message 'Confirmed Citrix Receiver is running.' -Function $MyInvocation.MyCommand.Name
    }
  }

  # Confirm Citrix XenApp shortcuts are available, and then launch frequently used apps
  if (test-path -Path "$env:USERPROFILE\Desktop\Assyst.lnk" -PathType Leaf) {
    Write-Output -InputObject 'Starting Citrix session ("H Drive")'
    Start-XenApp -Qlaunch 'H Drive'
    Write-Output -InputObject 'Pausing for Citrix (XenApp) session to load ...'
    Start-Sleep -Seconds 60

#    Write-Output -InputObject 'Starting Firefox (XenApp)'
#    xa_firefox
  } else {
    Write-Log -Message 'Unable to locate XenApp shortcuts. Please check network connectivity to workplace resources and try again.' -Function $MyInvocation.MyCommand.Name -Verbose
  }

  Show-Progress -msgAction 'Stop' -msgSource $MyInvocation.MyCommand.Name # Log end time stamp
  return $true # (Get-Process -Name Receiver).Description
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

    # Detect local Citrix Receiver version ... 14.7 = 4.7
    $file = "${env:ProgramFiles(x86)}\Citrix\ICA Client\concentr.exe"
    if (Test-Path -Path $file) {
        $CitrixVer = (Get-Command -Name $file).FileVersionInfo.ProductVersion
        Write-Verbose -Message "Detected Citrix receiver version $CitrixVer"
    } else {
        Write-Verbose -Message "Failed to detected Citrix receiver version"
        throw "Failed to locate Citrix file $file, to detect Product Version"
    }

    # Default GoForLaunch is false; switched to $true, if a valid app to Launch is checked.
    $Script:GoForLaunch = $false
    $Script:XenApps = @{}

    if ($CitrixVer -lt 14.2 ) {
        # Set XenApp 6 edition PNAgent ICA client
        Write-Verbose -Message 'Setting $ICAclient to pnagent.exe'
        Global:ICAClient = "${env:ProgramFiles(x86)}\Citrix\ICA Client\pnagent.exe"
        #  Load up $Setting.XenApp from sperry.json into Script scope $XenApps hashtable

        if (($Script:XenApps -eq 0) -and ([bool]$($Settings.XenApp)))
        {
            Write-Verbose -Message 'Reading available XenApp definitions from $Settings'
            $Settings.XenApp | ForEach-Object {
                Write-Verbose -Message "$($PSItem.Name) = $($ExecutionContext.InvokeCommand.ExpandString($PSItem.Qlaunch))"
                Write-Debug -Message "$($PSItem.Name) = $($ExecutionContext.InvokeCommand.ExpandString($PSItem.Qlaunch))"
                $script:XenApps.Add("$($PSItem.Name)",$ExecutionContext.InvokeCommand.ExpandString($PSItem.Qlaunch))
            }
        }
        else
        {
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

    # Process arguments
    $Private:Arguments = ''
    if ($Script:XenApps.Keys -contains $Launch)
    {
        Write-Verbose -Message "Matched `$Launch ('$Launch') in `$XenApps.Keys"
        if ($CitrixVer -lt 14.2) {
            $Private:Arguments = '/CitrixShortcut: (1)', "/QLaunch ""$($Script:XenApps.$Launch)"""
        } else {
            $Private:Arguments = "-qlaunch ""$Launch"""
        }
    }
    elseif ($Launch.Length -ge 2) {
        # if a shortcut key is not defined in $XenApps, pass the full 'string' e.g. GBCI02XA:Internet Explorer
        Write-Verbose -Message "Attempting to Launch ('$Launch')"
        if ($CitrixVer -lt 14.2) {
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

    if ($PSBoundParameters.ContainsKey('Reconnect'))
    {
        Write-Verbose -Message '($PSBoundParameters.ContainsKey(''Reconnect''))'
        Write-Verbose -Message ($PSBoundParameters.ContainsKey('Reconnect'))
        if ($CitrixVer -lt 14.2 ) {
            Write-Log -Message 'Start pnagent.exe /reconnect' -Function $PSCmdlet.MyInvocation.MyCommand.Name
            Start-Process $Global:ICAClient -ArgumentList '/reconnect' -PassThru
        } else {
            Write-Log -Message 'Start SelfService.exe –reconnectapps' -Function $PSCmdlet.MyInvocation.MyCommand.Name
            Start-Process $Global:ICAClient -ArgumentList '–reconnectapps' -PassThru
        }
    }
    elseif ($PSBoundParameters.ContainsKey('Terminate'))
    {
        Write-Verbose -Message '($PSBoundParameters.ContainsKey(''Terminate''))'
        Write-Verbose -Message ($PSBoundParameters.ContainsKey('Terminate'))
        if ($CitrixVer -lt 14.2 ) {
            Write-Log -Message 'Start pnagent.exe /TerminateWait' -Function $PSCmdlet.MyInvocation.MyCommand.Name
            Start-Process $Global:ICAClient -ArgumentList '/terminatewait' -PassThru
        } else {
            Write-Log -Message 'Start SelfService.exe -Terminate' -Function $PSCmdlet.MyInvocation.MyCommand.Name
            Start-Process $Global:ICAClient -ArgumentList '-terminate' -PassThru
        }
    }
    elseif ($PSBoundParameters.ContainsKey('ListAvailable'))
    {
        Write-Log -Message '`nEnumerating all available `$XenApps Keys' -Function $PSCmdlet.MyInvocation.MyCommand.Name -Verbose
        $Script:XenApps.Keys # | Sort-Object -Property Name | Format-Table -AutoSize
    } else {
        $Script:GoForLaunch = $true
    }

    write-Debug -Message "At the end, `$Private:Arguments is $Private:Arguments"

    # As long as we have non-0 arguments, run it using Start-Process and arguments list
    if ($Script:GoForLaunch) {
        if ($Private:Arguments -ne $NULL)
        {
            $Message = "Starting $($Arguments.Replace('/CitrixShortcut: (1) /QLaunch ',''))"
            $Message = "Starting $($Arguments.Replace('-qlaunch ',''))"
            Write-Log -Message $Message -Function $PSCmdlet.MyInvocation.MyCommand.Name -Verbose
            Start-Process $Global:ICAClient -ArgumentList "$Private:Arguments" -Verbose
        }
        else
        {
            Write-Log -Message "Unrecognized XenApp shortcut: $XenApp`n`tPlease try again with one of the following:" -Function $PSCmdlet.MyInvocation.MyCommand.Name -Verbose
            Write-Debug -Message $Script:XenApps.Keys
            $Script:XenApps.Keys # | Sort-Object -Property Name | Format-Table -AutoSize
            break
        }
    }

    Show-Progress -msgAction Stop -msgSource $PSCmdlet.MyInvocation.MyCommand.Name
}
