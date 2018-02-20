#!/usr/local/bin/powershell
#Requires -Version 3 -module PSLogger
#========================================
# NAME      : Microsoft.PowerShell_profile-Windows.ps1
# LANGUAGE  : Windows PowerShell
# AUTHOR    : Bryan Dady
# UPDATED   : 02/20/2018
# COMMENT   : Personal PowerShell Profile script, specific to running on a Windows host
#========================================
[CmdletBinding()]
param ()
#Set-StrictMode -Version latest

#Region MyScriptInfo
    Write-Verbose -Message '[CurrentUserCurrentHost Profile] Populating $MyScriptInfo'
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
        $Private:CallStack = Get-PSCallStack | Select-Object -First 1
        # $Private:CallStack | Select Position, ScriptName, Command | format-list # FunctionName, ScriptLineNumber, Arguments, Location
        $Private:MyScriptName = $Private:CallStack.ScriptName
        $Private:MyCommand = $Private:CallStack.Command
        Write-Verbose -Message "`$ScriptName: $Private:MyScriptName"
        Write-Verbose -Message "`$Command: $Private:MyCommand"
        Write-Verbose -Message 'Assigning previously null MyCommand variables with CallStack values'
        $Private:MyCommandPath = $Private:MyScriptName
        $Private:MyCommandName = $Private:MyCommand
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
    Write-Verbose -Message '[CurrentUserCurrentHost Profile] $MyScriptInfo populated'

    # Cleanup
    foreach ($var in $Private:properties.Keys) {
        Remove-Variable -Name ('My{0}' -f $var) -Force
    }

    $IsVerbose = $false
    if ('Verbose' -in $PSBoundParameters.Keys) {
        Write-Verbose -Message 'Output Level is [Verbose]. $MyScriptInfo is:'
        $IsVerbose = $true
        $Script:MyScriptInfo
    }
#End Region

Write-Output -InputObject ' # Loading PowerShell Windows Profile Script #'
Write-Verbose -Message (' ... from {0} # ' -f $MyScriptInfo.CommandPath)

# Define custom prompt format:
function prompt {
    [CmdletBinding()]
    param ()

    $IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')
    if($IsAdmin) {$AdminPrompt = '[ADMIN]:'} else {$AdminPrompt = ''}
    if(Get-Variable -Name PSDebugContext -ValueOnly -ErrorAction Ignore) {$DebugPrompt = '[DEBUG]:'} else {$DebugPrompt = ''}
    if(Get-Variable -Name PSConsoleFile -ValueOnly -ErrorAction Ignore)  {$PSCPrompt = "[PSConsoleFile: $PSConsoleFile]"} else {$PSCPrompt = ''}

    if($NestedPromptLevel -ge 1){ $PromptLevel = 'PS .\> >' } else { $PromptLevel = 'PS .\>'}

    return "[{0} @ {1}]`n{2}{3}{4}{5}" -f $env:ComputerName, $pwd.Path, $AdminPrompt, $PSCPrompt, $DebugPrompt, $PromptLevel
}

<# Yes! This even works in XenApp!
    & Invoke-Expression (New-Object Net.WebClient).DownloadString('http://bit.ly/e0Mw9w')
    # start-sleep -Seconds 3
#>

# Write-Debug -Message (' # # # $VerbosePreference: {0} # # #' -f $VerbosePreference)

Write-Verbose -Message 'Declaring function Invoke-WinSleep'
function Invoke-WinSleep {
  if ($onServer) {
    Write-Verbose -Message 'Invoke-WinSleep function is not for Server'
  } else {
    Write-Warning -Message 'Sleeping Windows in 30 seconds'
    'Enter Ctrl+C to abort'
    Start-Sleep -Seconds 30
    & "$env:windir\system32\rundll32.exe" powrprof.dll, SetSuspendState Sleep
  }
}
New-Alias -Name GoTo-Sleep -Value Invoke-WinSleep -ErrorAction Ignore
New-Alias -Name Sleep-PC -Value Invoke-WinSleep -ErrorAction Ignore

Write-Verbose -Message 'Declaring function Invoke-WinShutdown'
function Invoke-WinShutdown {
  if ($onServer) {
      Write-Verbose -Message 'Invoke-WinShutdown function is not for Server'
  } else {
    Write-Warning -Message 'Shutting down Windows in 30 seconds'
    'Run shutdown /a to abort'
    & "$env:windir\system32\shutdown.exe" /d p:0:0 /s /t 30
  }
}
New-Alias -Name Shutdown -Value Invoke-WinShutdown -ErrorAction Ignore
New-Alias -Name Shutdown-PC -Value Invoke-WinShutdown -ErrorAction Ignore

Write-Verbose -Message 'Declaring function Invoke-WinRestart'
function Invoke-WinRestart {
  if ($onServer) {
      Write-Verbose -Message 'Invoke-WinShutdown function is not for Server'
  } else {
    Write-Warning -Message 'Restarting Windows in 30 seconds'
    'Run shutdown /a to abort'
    & "$env:windir\system32\shutdown.exe" /d p:0:0 /r /t 30
  }
}
New-Alias -Name Restart -Value Invoke-WinRestart -ErrorAction Ignore

# Client-only tweaks(s) ...
if (-not $onServer) {
  # 'Fix' task bar icon grouping
  # I sure wish there was an API for this so I didn't have to restart explorer
  Write-Verbose -Message 'Checking Task Bar buttons display preference'
  if ($((Get-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name TaskbarGlomLevel).TaskbarGlomLevel) -ne 1) {
    Write-Output -InputObject 'Setting registry preference to group task bar icons, and re-starting explorer to activate the new setting.'
    Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name TaskbarGlomLevel -Value 1 -Force
    Start-Sleep -Milliseconds 50
    Get-Process -Name explorer* | Stop-Process
  }
}

Write-Debug -Message (' # # # $VerbosePreference: {0} # # #' -f $VerbosePreference)
Write-Verbose -Message 'Checking that .\scripts\ folder is available'
$atWork = $false
if (($variable:myPSScriptsPath) -and (Test-Path -Path $myPSScriptsPath -PathType Container)) {
  Write-Verbose -Message 'Loading scripts from .\scripts\ ...'
  Write-Output -InputObject ''

  # [bool]($NetInfo.IPAddress -match "^10\.\d{1,3}\.\d{1,3}\.\d{1,3}$") -or
  if (Test-Connection -ComputerName $env:USERDNSDOMAIN -Quiet) {
    $atWork = $true
  }

  Write-Verbose -Message ' ... loading NetSiteName.ps1'
  # dot-source script file containing Get-NetSite function
  . $myPSScriptsPath\NetSiteName.ps1

    Write-Verbose -Message '     Getting $NetInfo (IPAddress, SiteName)'
    # Get network / site info
    $NetInfo = Get-NetSite | Select-Object -Property IPAddress, SiteName -ErrorAction Stop
    if ($NetInfo) {
        $SiteType = 'remote'
        if ($atWork) {
            $SiteType = 'work'
        }
        Write-Output -InputObject ("Connected at {0} site: $($NetInfo.SiteName) (Address: $($NetInfo.IPAddress))" -f $SiteType) 
    } else {
        Write-Warning -Message ('Failed to enumerate Network Site Info: {0}' -f $NetInfo)
    }

    # dot-source script file containing Get-MyNewHelp function
    Write-Verbose -Message 'Initializing Get-MyNewHelp.ps1'
    . $myPSScriptsPath\Get-MyNewHelp.ps1
    
    # dot-source script file containing Citrix XenApp functions
    Write-Verbose -Message 'Initializing Start-XenApp.ps1'
    . $myPSScriptsPath\Start-XenApp.ps1
    
    Write-Verbose -Message 'Get-SystemCitrixInfo'
    # Confirms $Global:onServer and defines/updates $Global:OnXAHost, and/or fetched Receiver version
    Get-SystemCitrixInfo | Format-List
    
    # dot-source script file containing my XenApp functions
    Write-Verbose -Message 'Initializing GBCI-XenApp.ps1'
    . $myPSScriptsPath\GBCI-XenApp.ps1

} else {
    Write-Warning -Message ('Failed to locate Scripts folder {0}; run any scripts.' -f $myPSScriptsPath)
}

Write-Verbose -Message 'Declaring function Save-Credential'
function Save-Credential {
    [cmdletbinding(SupportsShouldProcess)]
    Param(
        [Parameter(Position = 0)]
        [string]
        $Variable = 'my2acct'
        ,
        [Parameter(Position = 1)]
        [string]
        $USERNAME = $(if ($IsWindows) {$env:USERNAME} else {$env:USER})
    )

    $SaveCredential = $false
    if ($Global:onServer) {
        Write-Verbose -Message ('Starting Save-Credential $Global:onServer = {0}' -f $Global:onServer)
        $VarValueSet = [bool](Get-Variable -Name $Variable -ValueOnly -ErrorAction SilentlyContinue)
        Write-Verbose -Message ('$VarValueSet = ''{0}''' -f $VarValueSet)
        if ($VarValueSet) {
            Write-Warning -Message ('Variable ''{0}'' is already defined' -f $Variable)
            if ((read-host -prompt ('Would you like to update/replace the credential stored in {0}`? [y]|n' -f $Variable)) -ne 'y') {
                Write-Warning -Message 'Ok. Aborting Save-Credential.'
            }
        } else {
            $SaveCredential = $true
        }

        Write-Verbose -Message ('$SaveCredential = {0}' -f $SaveCredential)
        if ($SaveCredential) {
            if ($USERNAME -NotMatch '\d$') {
                $UName = $($USERNAME + '2')
            } else {
                $UName = $USERNAME
            }

            Write-Output -InputObject ''
            Write-Output -InputObject ' # Prompting to capture elevated credentials. #'
            Write-Output -InputObject ' ...'
            Set-Variable -Name $Variable -Value $(Get-Credential -UserName $UName -Message 'Store admin credentials for convenient use later.') -Scope Global -Description 'Stored admin credentials for convenient re-use.'
            if ($?) {
                Write-Output -InputObject ('Elevated credentials stored in variable: {0}.' -f $Variable)
            }
        }
    } else {
        Write-Verbose -Message 'Skipping Save-Credential'
    }
} # end Save-Credential

New-Alias -Name rdp -Value Start-RemoteDesktop -ErrorAction Ignore
New-Alias -Name rename -Value Rename-Item -ErrorAction SilentlyContinue

#Region UpdateHelp
$UpdateHelp = $false
# Check if Write-Log function is available
if (Get-Command -Name Write-Log -CommandType Function -ErrorAction Ignore) {
    $UpdateHelp = $true
    Write-Debug -Message ('$UpdateHelp: {0}' -f $UpdateHelp)
} else {
    # This PowerShell session does not know about the Write-Log function, so we try to get a copy from the repository
    Get-Module -ListAvailable -Name PSLogger | Format-List -Property Name,Path,Version
    Write-Warning -Message 'Failed to locate Write-Log function locally. Attempting to load PSLogger module remotely'
    try {
        Get-PSDrive -PSProvider FileSystem -Name R -ErrorAction Stop
        Import-Module -Name R:\IT\PowerShell-Modules\PSLogger -ErrorAction Stop
        # double-check if Write-Log function is available
        if (Get-Command -Name Write-Log -CommandType Function -ErrorAction Stop) {
            $UpdateHelp = $true
            Write-Debug -Message ('$UpdateHelp: {0}' -f $UpdateHelp)
        }
    }
    catch {
        Write-Warning -Message 'No R: drive mapped. Get a copy of the PSLogger module installed, e.g. from R:\IT\PowerShell-Modules\PSLogger,'
        Write-Warning -Message 'then re-try Update-Help -SourcePath $HelpSource -Recurse -Module Microsoft.PowerShell.'
    }
}
Write-Verbose -Message ('$UpdateHelp: {0}' -f $UpdateHelp)

# Try to update PS help files, if we have local admin rights
# Check admin rights / role; same approach as Test-LocalAdmin function in Sperry module
$IsAdmin = $false;
if (Get-Variable -Name IsAdmin -ErrorAction Ignore) { 
    Write-Verbose -Message ('$IsAdmin: {0}' -f $IsAdmin);
} else {
    Write-Verbose -Message '$IsAdmin is not defined. Trying Test-LocalAdmin'
    if (Get-Command -Name Test-LocalAdmin -ErrorAction Ignore) { 
        $IsAdmin = Test-LocalAdmin;
    }
    Write-Verbose -Message ('$IsAdmin: {0}' -f $IsAdmin);
}

if ($UpdateHelp -and $IsAdmin) {
  # Define constant, for where to look for PowerShell Help files, in the local network
  $HelpSource = '\\hcdata\apps\IT\PowerShell-Help'

  if (($onServer) -and (Test-Path -Path $HelpSource)) {
    Write-Log -Message ('Preparing to update PowerShell Help from {0}' -f $HelpSource)
    Update-Help -SourcePath $HelpSource -Recurse -Module Microsoft.PowerShell.*
    Write-Log -Message 'PowerShell Core Help updated. To update help for all additional, available, modules, run Update-Help -SourcePath $HelpSource -Recurse'
  } else {
    Write-Log -Message ('Failed to access PowerShell Help path: {0}' -f $HelpSource)
  }
}
# else ... if not local admin, we don't have permissions to update help files.
#End Region

Write-Output -InputObject '# [PSEdit] #'
if (-not($Env:PSEdit)) {
    if (Test-Path -Path $HOME\vscode\app\code.exe -PathType Leaf) {
        Assert-PSEdit -Path (Resolve-Path -Path $HOME\vscode\app\code.exe)
    } else {
        Assert-PSEdit
    }
}
Write-Output -InputObject ''

# if connected to work network, initiate logging on to work, via Set-Workplace function
if ($atWork) {
    $thisHour = (Get-Date -DisplayHint Time).Hour
    # $OnXAHost = Get-ProcessByUser -ProcessName 'VDARedirector.exe' -ErrorAction Ignore
    if (($thisHour -ge 6) -and ($thisHour -le 18)) {
        Write-Verbose -Message 'Save-Credential'
        Save-Credential
        if ((-not $Global:onServer) -or $Global:OnXAHost) {
            Write-Output -InputObject ' # # # Start-CitrixSession # # #'
            # From .\Scripts\Start-XenApp.ps1
            Start-CitrixSession
        } elseif (-not $Global:onServer) {
            # From .\Scripts\GBCI-XenApp.ps1
            Write-Output -InputObject ' # # # Set-Workplace -Zone Office # # #'
            Set-Workplace -Zone Office
        }
    }
} else {
    Dismount-Path
    Write-Output -InputObject "`n # # # Work network not detected. Run 'Set-Workplace -Zone Remote' to switch modes.`n`n"
}

# Write-Output -InputObject '# Pre-log backup #'
# Write-Output -InputObject ('$VerbosePreference: {0} is {1}' -f $VerbosePreference, $IsVerbose)
# Backup local PowerShell log files
Write-Output -InputObject 'Archive PowerShell logs'
Backup-Logs
# Write-Output -InputObject '# Post-log backup #'
# Write-Output -InputObject ('$VerbosePreference: {0} is {1}' -f $VerbosePreference, $IsVerbose)

Write-Output -InputObject ' # End of PowerShell Windows Profile Script #'

<#
    # For intra-profile/bootstrap script flow Testing
    Write-Output -InputObject ''
    Start-Sleep -Seconds 3
#>