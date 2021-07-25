#!/usr/bin/env pwsh
#Requires -Version 5
#========================================
# NAME      : Bootstrap.ps1
# LANGUAGE  : Microsoft PowerShell
# AUTHOR    : Bryan Dady
# UPDATED   : 06/11/2019 - Improved script compatibility across Windows PowerShell (Desktop) and PowerShell Core (7 preview) on Linux and macOS
# COMMENT   : To be loaded / dot-sourced from a PowerShell profile script, to establish (bootstrap) baseline consistent environment variables,
#             regardless of PSEdition, Version, and/or operating system
#========================================
[CmdletBinding()]
param()
#Set-StrictMode -Version latest

# Uncomment the following 2 lines for testing profile scripts with Verbose output
#'$VerbosePreference = ''Continue'''
#$VerbosePreference = 'Continue'

Write-Verbose -Message 'Loading function Get-IsVerbose'
function Global:Get-IsVerbose {
    [CmdletBinding()]
    param ()

    Write-Debug -Message 'Detect -Verbose $VerbosePreference'

    switch ($VerbosePreference) {
        Stop             { $IsVerbose = $True }
        Inquire          { $IsVerbose = $True }
        Continue         { $IsVerbose = $True }
        SilentlyContinue { $IsVerbose = $False }
        Default          { if ('Verbose' -in $PSBoundParameters.Keys) {$IsVerbose = $True} else {$IsVerbose = $False} }
    }

    Write-Debug -Message ('$VerbosePreference: {0} is {1}' -f $VerbosePreference, $IsVerbose)

    $global:IsVerbose = $IsVerbose
    return $IsVerbose
}

Write-Verbose -Message ('$VerbosePreference = ''{0}'' : $IsVerbose = ''{1}''' -f $VerbosePreference, $IsVerbose)

Write-Verbose -Message 'Loading function Get-MyScriptInfo'
function Global:Get-MyScriptInfo {
    [CmdletBinding()]
    param ($MyInvocation)
    
    # region 
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
        'CommandRoot'        = Split-Path -Path $MyCommandPath -Parent
        'CommandType'        = $MyCommandType
        'CommandModule'      = $MyCommandModule
        'ModuleName'         = $MyModuleName
        'CommandParameters'  = $MyCommandParameters.Keys
        'ParameterSets'      = $MyParameterSets
        'RemotingCapability' = $MyRemotingCapability
        'Visibility'         = $MyVisibility
    }
    $MyScriptInfo = New-Object -TypeName PSObject -Property $properties -ErrorAction SilentlyContinue
    Write-Verbose -Message ('[{0}] $MyScriptInfo populated' -f $MyInvocation.MyCommand.Name)

    return $MyScriptInfo
}

$IsVerbose = Get-IsVerbose
$MyScriptInfo = Get-MyScriptInfo($MyInvocation)
$global:MyScriptInfo = $MyScriptInfo

if ($IsVerbose) { $MyScriptInfo }

# format output with some whitespace
Write-Output -InputObject ''
# Added Win10 PS 5.1 Support / Profile/PowerShell files in OneDrive path, including setting $HomePath to $MyScriptInfo.CommandPath, since Bootstrap.ps1 should always be in $HomePath
if ($MyScriptInfo.CommandPath -match 'OneDrive') {
    $InOneDrive = $true
    Write-Output -InputObject ' # # Initiating PowerShell Environment Bootstrap [OneDrive] #'
} else {
    $InOneDrive = $false
    Write-Output -InputObject ' # # Initiating PowerShell Environment Bootstrap #'
}
Write-Verbose -Message (' ... from {0}' -f $MyScriptInfo.CommandPath)


#Region HostOS
    # Detect older versions of PowerShell and add in new automatic variables for cross-platform consistency
    if ([Version]('{0}.{1}' -f $Host.Version.Major, $Host.Version.Minor) -le [Version]'5.1') {
        $global:IsWindows = $True
        $global:IsCoreCLR = $False
        $global:IsLinux   = $False
        $global:IsMacOS   = $False
        $global:IsAdmin   = $False
        $global:IsServer  = $False
        if (-not (Get-Variable -Name PSEdition -Scope Global -ErrorAction SilentlyContinue)) {
            if ($Host.Name -eq 'ConsoleHost') {
                $global:PSEdition = 'Desktop'
            }
        }
    }

    # Setup common variables for PS Core editions
    if (Get-Variable -Name IsWindows -ValueOnly -ErrorAction SilentlyContinue) {
        $hostOS = 'Windows'
        $hostOSInfo = Get-CimInstance -ClassName Win32_OperatingSystem -Property Caption, LastBootUpTime
        $LastBootUpTime = $hostOSInfo.LastBootUpTime # @{Name="Uptime";Expression={((Get-Date)-$_.LastBootUpTime -split '\.')[0]}}
        $hostOSCaption = $hostOSInfo.Caption -replace 'Microsoft ', ''
        if ($hostOSCaption -like '*Windows Server*') {
            $global:IsServer = $true
        }

        # Check admin rights / role; same approach as Test-LocalAdmin function in Sperry module
        $global:IsAdmin = (([security.principal.windowsprincipal] [security.principal.windowsidentity]::GetCurrent()).isinrole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
    }

    if (Get-Variable -Name IsLinux -ValueOnly -ErrorAction SilentlyContinue) {
        $hostOS = 'Linux'
        $hostOSCaption = $(uname -mrs)
        $OS_INFO = cat /etc/*-release | ConvertFrom-StringData
        if ('PRETTY_NAME' -in $OS_INFO.keys) {
            # the -replace handler removes superfluous double-quote characters
            $hostOSCaption = $OS_INFO.PRETTY_NAME -replace "\"""
        }
        if (-not (Test-Path -LiteralPath Env:COMPUTERNAME -ErrorAction SilentlyContinue)) {
            $Env:COMPUTERNAME = $(hostname)
        }
    }

    if (Get-Variable -Name IsMacOS -ValueOnly -ErrorAction SilentlyContinue) {
        # !RFE: enhance dynamic hostOS and hostOSCaption population and evaluation
        $hostOS = 'macOS'
        $hostOSCaption = ('{0} {1}' -f $(sw_vers -productName), $(sw_vers -productVersion)) # $(uname -mrs)
        if (-not (Test-Path -LiteralPath Env:ComputerName -ErrorAction SilentlyContinue)) {
            $Env:COMPUTERNAME = $(hostname)
        }
    }

    Write-Output -InputObject ''
    Write-Output -InputObject (' # {0} {1} {2} on {3} - {4} #' -f $ShellId, $Host.version.toString().substring(0,3), $PSEdition, $hostOSCaption, $Env:ComputerName)

    Write-Verbose -Message ('Setting environment SHELL to {0} {1} {2}' -f $ShellId, $PSEdition, $PSVersionTable.PSVersion.ToString())
    $Env:SHELL = ('{0} {1} {2}' -f $ShellId, $PSEdition, $PSVersionTable.PSVersion.ToString())
    $GLOBAL:SHELL=$(which pwsh)

    Write-Verbose -Message ('Setting environment HostOS to {0}' -f $hostOS)
    $Env:HostOS = $hostOS

#End Region HostOS

if ($IsVerbose) { Write-Output -InputObject '' }

#Region Check $HOME
    # If running from a server / networked context, prefer non-local $HOME path
    if ($IsServer -and (-not $InOneDrive)) {
        # Derive full path to user's $HOME and PowerShell folders
        Write-Verbose -Message 'IsServer = True; Checking if $HOME is on the SystemDrive'
        Write-Debug -Message ('$Home is: {0}.' -f $Home)
        $HomePath = Resolve-Path -Path $HOME
        Write-Verbose -Message ('$HomePath is: {0}.' -f $HomePath)
        # If $HOME is on the SystemDrive, then it's not the right $HOME we're looking for
        if ($Env:SystemDrive -eq $HomePath.Path.Substring(0,2)) {
            Write-Warning -Message ('Operating in a Server OS and $HOME ''{0}'' is on SystemDrive. Looking for a network HOME path' -f $HOME)
            # Detect / derive a viable (new) $HOME root, by looking at the HOMEDRIVE, HOMEPATH system variables
            $PreviousErrorActionPreference = $ErrorActionPreference
            $ErrorActionPreference = 'SilentlyContinue'
            if (Test-Path -Path ('{0}{1}' -f $Env:HOMEDRIVE, $Env:HOMEPATH)) {
                Write-Verbose -Message ('Determined {0}{1} ($Env:HOMEDRIVE+$Env:HOMEPATH) is available' -f $Env:HOMEDRIVE, $Env:HOMEPATH)
                $HomePath = Join-Path -Path $Env:HOMEDRIVE -ChildPath $Env:HOMEPATH
            } else {
                Write-Verbose -Message ('Determined {0}{1} ($Env:HOMEDRIVE+$Env:HOMEPATH) is NOT available; trying ''H:\''' -f $Env:HOMEDRIVE, $Env:HOMEPATH)
                if (Test-Path -Path (Join-Path -Path 'H:\' -ChildPath '*Documents')) {
                    $HomePath = 'H:\'
                } else {
                    Write-Warning -Message 'H:\ does not appear to contain a [My ]Documents folder, so it''s not a reliable $HOME path.'
                }
            }
            $ErrorActionPreference = $PreviousErrorActionPreference
            Remove-Variable -Name PreviousErrorActionPreference
        }

        # Next, (Re-)confirm a viable [My ]Documents subfolder, and update the $HomePath variable for later re-use/reference
        if (Test-Path -Path (Join-Path -Path $HomePath -ChildPath '*Documents' -Resolve)) {
            $HomeDocsPath = (Join-Path -Path $HomePath -ChildPath '*Documents' -Resolve)
            Write-Verbose -Message ('Confirmed $HomePath contains a Documents folder: {0}' -f $HomeDocsPath)
            if ($HOME -ne $HomePath) {
                # Update $HOME to match updated $HomePath
                Write-Verbose -Message ('Updating $HOME to $HomePath: {0}' -f $HomePath)
                Set-Variable -Name HOME -Value $HomePath -Scope Global -Force -ErrorAction Stop
            }
        } else {
            Write-Warning -Message 'Failed to confirm a reliable $HOME (user) folder. Consider updating $HOME and trying again.'
            break
        }
    }

    # Bootstrap is intended to live next to User Profile (pwsh) scripts, so regardless of PSEdition (Core or Desktop), it's root should be $myPSHome
    $global:myPSHome =$MyScriptInfo.CommandRoot

    if ($IsWindows) {
        # In Windows, semicolon is used to separate entries in the PATH variable
        $PathSplitChar = ';'

        #Define modules, scripts, and log folders within user's PowerShell folder, creating the SubFolders if necessary
        $myPSModulesPath = (Join-Path -Path $myPSHome -ChildPath 'Modules')
        if (-not (Test-Path -Path $myPSModulesPath)) {
            New-Item -Path $myPSHome -ItemType Directory -Name 'Modules'
        }
        Set-Variable -Name myPSModulesPath -Value $myPSModulesPath -Force -Scope Global

        $myPSScriptsPath = (Join-Path -Path $myPSHome -ChildPath 'Scripts')
        if (-not (Test-Path -Path $myPSScriptsPath)) {
            New-Item -Path $myPSHome -ItemType Directory -Name 'Scripts'
        }
        Set-Variable -Name myPSScriptsPath -Value $myPSScriptsPath -Force -Scope Global

        $myPSLogPath = (Join-Path -Path $myPSHome -ChildPath 'log')
        if (-not (Test-Path -Path $myPSLogPath)) {
            New-Item -Path $myPSHome -ItemType Directory -Name 'log'
        }
        Set-Variable -Name myPSLogPath -Value $myPSLogPath -Force -Scope Global

    } else {
        # Setup "MyPS" variables with PowerShell (pwsh) common paths for non-Windows / PS Core host
        # https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-linux?view=powershell-6#paths
        # User profiles will be read from ~/.config/powershell/profile.ps1 (and for our purposes, user Scripts should be in the same place)
        $myPSScriptsPath = "~/.config/powershell/scripts"
        if (-not (Test-Path -Path $myPSScriptsPath)) {
            New-Item -Path "~/.config/powershell/" -ItemType Directory -Name 'scripts'
        }
        Set-Variable -Name myPSScriptsPath -Value $myPSScriptsPath -Force -Scope Global

        # User modules will be read from ~/.local/share/powershell/Modules
        $myPSModulesPath = "~/.local/share/powershell/Modules"
        if (-not (Test-Path -Path $myPSModulesPath)) {
            New-Item -Path "~/.local/share/powershell" -ItemType Directory -Name 'Modules'
        }
        Set-Variable -Name myPSModulesPath -Value $myPSModulesPath -Force -Scope Global

        # In non-Windows OS, colon character is used to separate entries in the PATH variable
        $PathSplitChar = ':'
        if (-not (Test-Path -Path $HOME)) {
            Write-Verbose -Message 'Setting $HOME to $myPSHome'
            Set-Variable -Name HOME -Value $(Split-Path -Path $myPSHome -Parent) -Force
        }
    }

    # Copy local variable myPSHome to Global scope
    Set-Variable -Name myPSHome -Value $myPSHome -Force -Scope Global

    Write-Verbose -Message ('$myPSHome is {0}' -f $myPSHome)
    if (Get-Variable -Name myPSHome) {
        if (Test-Path -Path $GLOBAL:myPSHome -ErrorAction SilentlyContinue) {
            write-output -InputObject ''
            Write-Output -InputObject ('PS .\> {0}' -f (Push-Location -Path $myPSHome -PassThru | Select-Object -Property Path).Path)
            write-output -InputObject ''
        } else {
            Write-Warning -Message 'Failed to establish / locate path to user PowerShell directory. Creating default locations.'
            if (Test-Path -Path $myPSHome -IsValid -ErrorAction Stop) {
                New-Item -ItemType 'Directory' -Path ('{0}' -f $myPSHome) -Confirm
            } else {
                throw 'Fatal error confirming or setting up PowerShell user root: $myPSHome'
            }
        }
    } else {
        throw 'Fatal error: $myPSHome is empty or null'
    }
#End Region

Write-Output -InputObject ''
Write-Output -InputObject ' # # PowerShell Environment Bootstrap Complete #'
Write-Output -InputObject ''

# For intra-profile/bootstrap script flow Testing
if ($IsVerbose) {
    Write-Output -InputObject 'Verbose/testing: pausing before proceeding'
    Start-Sleep -Seconds 3
}
