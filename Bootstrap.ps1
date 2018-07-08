#!/usr/local/bin/pwsh
#Requires -Version 3
#========================================
# NAME      : Bootstrap.ps1
# LANGUAGE  : Microsoft PowerShell
# AUTHOR    : Bryan Dady
# UPDATED   : 05/8/2018 - Improved script compatibility across Windows PowerShell (Desktop) and PowerShell Core, such as Is* variables and PSEdition support
# COMMENT   : To be loaded / dot-sourced from a PowerShell profile script.
#             Checks for and use a network share (UNC) based $HOME, such as from a domain server, and additional network PowerShell session environment setup.
#========================================
[CmdletBinding()]
param()
#Set-StrictMode -Version latest

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
    Write-Verbose -Message '[Bootstrap] Populating $MyScriptInfo'
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
    Write-Verbose -Message '[Bootstrap] $MyScriptInfo populated'

    if ($IsVerbose) {
        Write-Verbose -Message '$MyScriptInfo:'
        $Script:MyScriptInfo
    }
#End Region

Write-Output -InputObject ' # # Initiating PowerShell Environment Bootstrap #'
Write-Verbose -Message (' ... from {0} #' -f $MyScriptInfo.CommandPath)

#Region HostOS
    <#
        Get-Variable -Name Is* -Exclude ISERecent | FT

        Name                           Value
        ----                           -----
        IsAdmin                        False
        IsCoreCLR                      True
        IsLinux                        False
        IsMacOS                        True
        IsWindows                      False
    #>

    # Detect older versions of PowerShell and add in new automatic variables for cross-platform consistency
    if ([Version]('{0}.{1}' -f $Host.Version.Major, $Host.Version.Minor) -le [Version]'5.1') {
        $Global:IsWindows = $true
        $Global:IsCoreCLR = $False
        $Global:IsLinux   = $False
        $Global:IsMacOS   = $False
        $Global:IsAdmin   = $False
        if (-not $PSEdition) {
            $Global:PSEdition = 'Desktop'
        }
    }

    # Setup common variables for PS Core editions
    if (Get-Variable -Name IsWindows -ValueOnly -ErrorAction SilentlyContinue) {
        $hostOS = 'Windows'
        $hostOSCaption = $((Get-CimInstance -ClassName Win32_OperatingSystem -Property Caption).Caption) -replace 'Microsoft ', ''
        # Check admin rights / role; same approach as Test-LocalAdmin function in Sperry module
        $Global:IsAdmin = (([security.principal.windowsprincipal] [security.principal.windowsidentity]::GetCurrent()).isinrole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
    }

    if (Get-Variable -Name IsLinux -ValueOnly -ErrorAction SilentlyContinue) {
        $hostOS = 'Linux'
        $hostOSCaption = $hostOS
        if (-not (Test-Path -LiteralPath Env:ComputerName -ErrorAction SilentlyContinue)) {
            $Env:ComputerName = $(hostname)
        }
    }

    if (Get-Variable -Name IsMacOS -ValueOnly -ErrorAction SilentlyContinue) {
        $hostOS = 'macOS'
        $hostOSCaption = $hostOS
        if (-not (Test-Path -LiteralPath Env:ComputerName -ErrorAction SilentlyContinue)) {
            $Env:ComputerName = $(hostname)
        }
    }

    # ' # Test output #'
    # Get-Variable -Name Is* -Exclude ISERecent Format-Table

    Write-Output -InputObject ''
    Write-Output -InputObject " # $ShellId $($Host.version.toString().substring(0,3)) $PSEdition on $hostOSCaption - $Env:ComputerName #"

    Write-Verbose -Message ('Setting environment HostOS to {0}' -f $hostOS)
    $Env:HostOS = $hostOS

    $Global:onServer = $false
    $Global:onXAHost = $false
    if ($hostOSCaption -like '*Windows Server*') {
        $Global:onServer = $true
    }
#End Region HostOS

if ($IsVerbose) { Write-Output -InputObject '' }

#Region Check $HOME
    # Derive full path to user's $HOME and PowerShell folders
    Write-Verbose -Message ('$HOME is: {0}.' -f $HOME)
    if ($Global:HOME -and (Test-Path -Path $Global:HOME)) {
        Write-Verbose -Message '   and $HOME is accessible.'
    } else {
        # $HOME is NOT set or available, so set it to match $Env:USERPROFILE
        Write-Output  -InputObject ''
        Write-Warning -Message ' # Failed to access $HOME; Defaulting to $Env:USERPROFILE'
        Write-Output  -InputObject ''
        Write-Verbose -Message ('Updating $HOME to {0}.' -f $Env:USERPROFILE)
        Set-Variable  -Name HOME -Value (Resolve-Path -Path $Env:USERPROFILE) -Force
    }

    $HomePath = Resolve-Path -Path $HOME
    Write-Debug -Message ('$HomePath is: {0}.' -f $HomePath)
    # If running from a server / networked context, prefer non-local $HOME path
    if ($Global:onServer) {
        Write-Verbose -Message 'Checking if $HOME is on the SystemDrive'
        # If $HOME is on the SystemDrive, then it's not the right $HOME we're looking for
        if ($Env:SystemDrive -eq $HomePath.Path.Substring(0,2)) {
            Write-Warning -Message ('$HOME ''{0}'' is on SystemDrive. Looking for a network HOME path' -f $HOME)
            # Detect / derive a viable (new) $HOME root, by looking at the HOMEDRIVE, HOMEPATH system variables
            $Private:PreviousErrorActionPreference = $ErrorActionPreference
            $ErrorActionPreference = 'SilentlyContinue'
            if (Test-Path -Path ('{0}{1}' -f $Env:HOMEDRIVE, $Env:HOMEPATH)) {
                Write-Verbose -Message ('Determined {0}{1} ($Env:HOMEDRIVE+$Env:HOMEPATH) is available' -f $Env:HOMEDRIVE, $Env:HOMEPATH)
                $HomePath = Join-Path -Path $Env:HOMEDRIVE -ChildPath $Env:HOMEPATH -Resolve
            } else {
                        Write-Verbose -Message ('Determined {0}{1} ($Env:HOMEDRIVE+$Env:HOMEPATH) is NOT available; trying ''H:\''' -f $Env:HOMEDRIVE, $Env:HOMEPATH)
                if (Test-Path -Path (Join-Path -Path 'H:\' -ChildPath '*Documents')) {
                    $HomePath = Resolve-Path -Path 'H:\'
                } else {
                    Write-Verbose -Message ('$HomePath ''{0}'' does not appear to contain a [My ]Documents folder, so it''s not a reliable $HOME path. Trying H:\' -f $HomePath)
                }
            }
            $ErrorActionPreference = $Private:PreviousErrorActionPreference
        }
    } else {
        # If running from a desktop / client, prefer local $HOME path
        Write-Debug   -Message ('$MyScriptInfo.CommandPath.Substring(0,3): {0}.' -f $MyScriptInfo.CommandPath.Substring(0,3))
        Write-Debug   -Message ('$HomePath.Path.Substring(0,3): {0}.' -f $HomePath.Path.Substring(0,3))
        if ($MyScriptInfo.CommandPath.Substring(0,3) -eq $HomePath.Path.Substring(0,3)) {
            Write-Verbose -Message ('$HOME checks out as local: {0}.' -f $HOME)
        } else {
            Write-Verbose -Message ('Updating $HOME to local USERPROFILE: {0}.' -f $Env:USERPROFILE)
            $HomePath = Resolve-Path -Path $Env:USERPROFILE
        }
    }

    # Compare Path properties, as the objects are not reliably 'equal'
    Write-Verbose -Message ('$HomePath.Path: {0}.' -f $HomePath.Path)
    Write-Verbose -Message ('$HOME.Path: {0}.' -f $HOME.Path)
    #if ($HomePath.Path -ne $HOME.Path) {
        # Update $HOME to match updated $HomePath
        Write-Verbose -Message ('Updating $HOME to $HomePath: {0}' -f $HomePath)
        Set-Variable -Name HOME -Value (Resolve-Path -Path $HomePath) -Force
    #}

    # Next, (Re-)confirm a viable [My ]Documents subfolder, and update the $myPSHome variable for later re-use/reference
    if (Test-Path -Path (Join-Path -Path $HomePath -ChildPath '*Documents' -Resolve)) {
        Write-Verbose -Message ('Confirmed valid $HomePath: {0}' -f $HomePath)
        Write-Verbose -Message ('Confirmed valid $HOME Path: {0}' -f $HOME)
    } else {
        Write-Warning -Message 'Failed to find a reliable $HOME path. Consider updating $HOME and trying again.'
        break
    }

    if ($IsWindows) {
        # Adjust [My ]Documents ChildPath for PSEdition (Core or Desktop)
        $MyDocs = (Join-Path -Path $HOME -ChildPath '*Documents' -Resolve)
        $myPSHome = ('{0}\WindowsPowerShell' -f $MyDocs)
        if (($Global:HOME -like "$Env:SystemDrive*") -and ($PSEdition -eq 'Core')) {
            Write-Verbose -Message 'Using local PS Core path: ''PowerShell''.' -Verbose
            $myPSHome = ('{0}\PowerShell' -f $MyDocs)
        }
    } else {
        # Setup "MyPS" variables with PowerShell (pwsh) common paths for non-Windows / PS Core host
        # https://docs.microsoft.com/en-us/powershell/scripting/whats-new/what-s-new-in-powershell-core-60
        # The history save path is located at ~/.local/share/powershell/PSReadline/ConsoleHost_history.txt
        # The user module path is located at ~/.local/share/powershell/Modules
        $myPSHome = ('{0}.local/share/powershell' -f '~')
        #Set-Variable -Name myPSHome -Value (Join-Path -Path $HOME -ChildPath $ChildPath -Resolve) -Force -Scope Global
    }

    Set-Variable -Name myPSHome -Value $myPSHome -Force -Scope Global

    if (Get-Variable -Name myPSHome) {
        if (Test-Path -Path $GLOBAL:myPSHome -ErrorAction SilentlyContinue) {
            Write-Verbose -Message ('$myPSHome is {0}' -f $myPSHome)
            write-output -InputObject ''
            Write-Output -InputObject ('PS .\> {0}' -f (Push-Location -Path $myPSHome -PassThru | Select-Object -Property Path).Path)
            write-output -InputObject ''
        } else {
            Write-Warning 'Failed to establish / locate path to user PowerShell directory. Creating default locations.'
            if (Test-Path -Path $myPSHome -IsValid -ErrorAction Stop) {
                New-Item -ItemType 'directory' -Path ('{0}' -f $myPSHome)
            } else {
                throw 'Fatal error confirming or setting up PowerShell user root: $myPSHome'
            }
        }
    } else {
        throw 'Fatal error: $myPSHome is empty or null'
    }
#End Region

#Region ModulePath
    # check and conditionally update/fix PSModulePath
    Write-Verbose -Message 'Checking $Env:PSModulePath for user modules path ($myPSModulesPath)'
    if ($IsWindows) {
        # In Windows, semicolon is used to separate entries in the PATH variable
        $Private:SplitChar = ';'

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
        # In non-Windows OS, colon character is used to separate entries in the PATH variable
        $Private:SplitChar = ':'
        if (-not (Test-Path -Path $HOME)) {
            Write-Verbose -Message 'Setting $HOME to $myPSHome'
            Set-Variable -Name HOME -Value $(Split-Path -Path $myPSHome -Parent) -Force
        }
    }

    Write-Verbose -Message ('My PS Modules Path: {0}' -f $myPSModulesPath)

    Write-Debug -Message ('($myPSModulesPath -in @($Env:PSModulePath -split $Private:SplitChar) = {0}' -f ($myPSModulesPath -in @($Env:PSModulePath -split $Private:SplitChar)))
    if (($null -ne $myPSModulesPath) -and (-not ($myPSModulesPath -in @($Env:PSModulePath -split $Private:SplitChar)))) {
        Write-Verbose -Message ('Adding Modules Path: {0} to $Env:PSModulePath' -f $myPSModulesPath) -Verbose
        $Env:PSModulePath += ('{0}{1}' -f $Private:SplitChar, $myPSModulesPath)

        # post-update cleanup
        if (Test-Path -Path (Join-Path -Path $myPSScriptsPath -ChildPath 'Cleanup-ModulePath.ps1') -ErrorAction SilentlyContinue) {
            & $myPSScriptsPath\Cleanup-ModulePath.ps1
            Write-Output -InputObject $Env:PSModulePath
        }
    }
#End Region ModulePath

Write-Verbose -Message 'Declaring function Get-CustomModule'
function Get-CustomModule {
    return Get-Module -ListAvailable | Where-Object -FilterScript {$PSItem.ModuleType -eq 'Script' -and $PSItem.Author -NotLike 'Microsoft Corporation'}
}

write-output -InputObject ''
write-output -InputObject ' # To enumerate available Custom Modules, run:'
write-output -InputObject '   # Get-CustomModule | Format-Table -Property Name, Description'

write-output -InputObject '   # To view additional available modules, run: Get-Module -ListAvailable'
Write-Output -InputObject '   # To view cmdlets available in a given module, run:'
Write-Output -InputObject '   #  Get-Command -Module <ModuleName>'

Write-Output -InputObject ''
Write-Output -InputObject ' # # PowerShell Environment Bootstrap Complete #'
Write-Output -InputObject ''

# Uncomment the following line for testing / pausing between profile/bootstrap scripts
#Start-Sleep -Seconds 5
