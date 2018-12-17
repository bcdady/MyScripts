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

# Added Win10 PS 5.1 Support / Profile/PowerShell files in OneDrive path, including setting $HomePath to $MyScriptInfo.CommandPath, since Bootstrap.ps1 should always be in $myPShome
if ($MyScriptInfo.CommandPath -match 'OneDrive') {
    $InOneDrive = $true
    Write-Output -InputObject ' # # Initiating PowerShell Environment Bootstrap [OneDrive]#'
} else {
    $InOneDrive = $false
    Write-Output -InputObject ' # # Initiating PowerShell Environment Bootstrap #'
}
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
        $hostOSInfo = Get-CimInstance -ClassName Win32_OperatingSystem -Property Caption, LastBootUpTime
        $LastBootUpTime = $hostOSInfo.LastBootUpTime # @{Name="Uptime";Expression={((Get-Date)-$_.LastBootUpTime -split '\.')[0]}}
        $hostOSCaption = $hostOSInfo.Caption -replace 'Microsoft ', ''
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
    Write-Output -InputObject (' # {0} {1} {2} on {3} - {4} #' -f $ShellId, $Host.version.toString().substring(0,3), $PSEdition, $hostOSCaption, $Env:ComputerName)

    Write-Verbose -Message ('Setting environment HostOS to {0}' -f $hostOS)
    $Env:HostOS = $hostOS

    $Global:onServer = $false
    $Global:onXAHost = $false
    if ($hostOSCaption -like '*Windows Server*') {
        $Global:onServer = $true
    }
#End Region HostOS

if ($IsVerbose) { Write-Output -InputObject '' }

#Region myPSHome
    # Derive full path to user's $HOME and PowerShell folders
    <#
        Write-Verbose -Message ('$HOME is: {0}.' -f $HOME)
        if ($Global:HOME -and (Test-Path -Path $Global:HOME)) {
            Write-Verbose -Message '   and $HOME is accessible.'
        } else {
            # $HOME is NOT set or available, so set it to match $Env:USERPROFILE
            Write-Output  -InputObject ''
            Write-Warning -Message ' # Failed to access $HOME; Setting to $MyScriptInfo.CommandPath'
            Write-Output  -InputObject ''
            Write-Verbose -Message ('Updating $HOME to {0}.' -f $MyScriptInfo.CommandPath)
            Set-Variable  -Name HOME -Value (Resolve-Path -Path $MyScriptInfo.CommandPath) -Force
        }
    #>

    $myPSHome = Resolve-Path -Path (Split-Path -Path $MyScriptInfo.CommandPath)
    Write-Debug -Message ('$myPSHome is: {0}.' -f $myPSHome)
    # If running from a server / networked context, prefer non-local $HOME path
    if ($Global:onServer) {
        Write-Verbose -Message 'Checking if currently running in the SystemDrive'
        # If so, then we should look for another (better?) option
    <#
        if ($Env:SystemDrive -eq $myPSHome.Path.Split('\')[0])) {
            Write-Warning -Message ('$HOME ''{0}'' is on SystemDrive. Looking for a network HOME path' -f $HOME)
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
    #>
    } else {
        # If running from a desktop / client, prefer local $HOME path
        if ($MyScriptInfo.CommandPath.Split('\')[0] -eq $myPSHome.Path.Split('\')[0]) {
            Write-Verbose -Message ('$myPSHome checks out as local: {0}.' -f $myPSHome)
        } else {
            Write-Warning -Message ('$myPSHome is NOT local: {0}.' -f $myPSHome)
            # $myPSHome = Resolve-Path -Path $Env:USERPROFILE
        }
    }

    <#
        # Update $HOME to the root of $myPSHome
        Write-Verbose -Message ('Updating $HOME to $HomePath: {0}' -f $HomePath)
        Set-Variable -Name HOME -Value $HomePath -Force -ErrorAction Stop

        # Next, (Re-)confirm a viable [My ]Documents subfolder, and update the $myPSHome variable for later re-use/reference
        if (Test-Path -Path (Join-Path -Path $HOME -ChildPath '*Documents' -Resolve)) {
            # Write-Verbose -Message ('Confirmed valid $HomePath: {0}' -f $HomePath)
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
    #>

    Set-Variable -Name myPSHome -Value $myPSHome -Force -Scope Global

    if (Get-Variable -Name myPSHome) {
        if (Test-Path -Path $GLOBAL:myPSHome -ErrorAction SilentlyContinue) {
            Write-Verbose -Message ('$myPSHome is {0}' -f $myPSHome)
            write-output -InputObject ''
            Write-Output -InputObject ('PS .\> {0}' -f (Push-Location -Path $myPSHome -PassThru | Select-Object -Property Path).Path)
            write-output -InputObject ''
        } else {
            Write-Warning -Message 'Failed to establish / locate path to user PowerShell directory. Creating default locations.'
            if (Test-Path -Path $myPSHome -IsValid -ErrorAction Stop) {
                New-Item -ItemType 'directory' -Path ('{0}' -f $myPSHome)
            } else {
                throw 'Fatal error confirming or setting up PowerShell user root: $myPSHome'
            }
        }
    } else {
        throw 'Fatal error: $myPSHome is empty or null'
    }
    # Remove-Variable -Name MyDocs -ErrorAction SilentlyContinue
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
        $SplitChar = ':'
        if (-not (Test-Path -Path $HOME)) {
            Write-Verbose -Message 'Setting $HOME to $myPSHome'
            Set-Variable -Name HOME -Value $(Split-Path -Path $myPSHome -Parent) -Force
        }
    }

    Write-Verbose -Message ('My PS Modules Path: {0}' -f $myPSModulesPath)

    Write-Debug -Message ('($myPSModulesPath -in @($Env:PSModulePath -split $SplitChar) = {0}' -f ($myPSModulesPath -in @($Env:PSModulePath -split $SplitChar)))
    if (($null -ne $myPSModulesPath) -and (-not ($myPSModulesPath -in @($Env:PSModulePath -split $SplitChar)))) {
        Write-Verbose -Message ('Adding Modules Path: {0} to $Env:PSModulePath' -f $myPSModulesPath) -Verbose
        $Env:PSModulePath += ('{0}{1}' -f $SplitChar, $myPSModulesPath)

        # post-update cleanup
        if (Test-Path -Path (Join-Path -Path $myPSScriptsPath -ChildPath 'Cleanup-ModulePath.ps1') -ErrorAction SilentlyContinue) {
            & $myPSScriptsPath\Cleanup-ModulePath.ps1
            Write-Output -InputObject $Env:PSModulePath
        }
    }
    Remove-Variable -Name SplitChar -ErrorAction SilentlyContinue
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
