#!/usr/local/bin/powershell
#Requires -Version 3
#========================================
# NAME      : Bootstrap.ps1
# LANGUAGE  : Windows PowerShell
# AUTHOR    : Bryan Dady
# UPDATED   : 01/18/2018 - Updated splitChar to a Private variable
# COMMENT   : To be loaded / dot-sourced from a PowerShell profile script.
#             Checks for and use a network share (UNC) based $HOME, such as from a domain server, and additional network PowerShell session environment setup.
#========================================
[CmdletBinding()]
param()
Set-StrictMode -Version latest

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

    if ('Verbose' -in $PSBoundParameters.Keys) {
        Write-Verbose -Message 'Output Level is [Verbose]. $MyScriptInfo is:'
        $MyScriptInfo
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
    if ($Host.Version.Major -le 5) {
        $Global:IsWindows = $true
        $Global:PSEdition = 'Windows'
        $Global:IsAdmin   = $False
        $Global:IsCoreCLR = $False
        $Global:IsLinux   = $False
        $Global:IsMacOS   = $False
    }

    if (Get-Variable -Name IsLinux -ValueOnly -ErrorAction Ignore) {
        $hostOS = 'Linux'
        $hostOSCaption = $hostOS
        if (-not (Test-Path -LiteralPath env:ComputerName -ErrorAction Ignore)) { 
            $env:ComputerName = $(hostname)
        }
        # Check admin rights / role; same approach as Test-LocalAdmin function in Sperry module
        #$IsAdmin = ... ?
    }

    if (Get-Variable -Name IsMacOS -ValueOnly -ErrorAction Ignore) { 
        $hostOS = 'macOS'
        $hostOSCaption = $hostOS
        if (-not (Test-Path -LiteralPath env:ComputerName -ErrorAction Ignore)) { 
            $env:ComputerName = $(hostname)
        }
        # Check admin / root rights / role
        #$IsAdmin = ... ?
    } 

    if ($IsWindows) {
        $hostOS = 'Windows'
        $hostOSCaption = $((Get-CimInstance -ClassName Win32_OperatingSystem -Property Caption).Caption) -replace 'Microsoft ', ''
        # Check admin rights / role; same approach as Test-LocalAdmin function in Sperry module
        $IsAdmin = (([security.principal.windowsprincipal] [security.principal.windowsidentity]::GetCurrent()).isinrole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
    }

    # ' # Test output #'
    # Get-Variable -Name Is* -Exclude ISERecent | FT

    Write-Output -InputObject ''
    Write-Output -InputObject " # $ShellId $($Host.version.toString().substring(0,3)) $PSEdition on $hostOSCaption - $env:ComputerName #"

    Write-Verbose -Message ('Setting environment HostOS to {0}' -f $hostOS)
    $env:HostOS = $hostOS

    $Global:onServer = $false
    $Global:onXAHost = $false
    if ($hostOSCaption -like '*Windows Server*') {
        $Global:onServer = $true
    }
#End Region HostOS

#Region Check$HOME
    # Derive full path to user's $HOME and PowerShell folders
    if ($IsWindows) {
        Write-Verbose -Message 'Checking if $HOME is on the Windows SystemDrive'
        # If $HOME is on the SystemDrive, then it's not the right $HOME we're looking for
        if ($Global:HOME -like "$Env:SystemDrive*") {
            Write-Warning -Message ('$HOME ''{0}'' is on SystemDrive. Looking for another possible HOME path' -f $HOME)
            # Try to figure out where the non-local-system $HOME is
            if (Test-Path -Path "$Env:HOMEDRIVE$Env:HOMEPATH") {
                $HomePath = Join-Path -Path $Env:HOMEDRIVE -ChildPath $Env:HOMEPATH -Resolve

                if (Test-Path -Path "$HomePath\*Documents") {
                    $HomePath = Join-Path -Path $Env:HOMEDRIVE -ChildPath $Env:HOMEPATH -Resolve
                    Write-Verbose -Message ('Confirmed {0} is available' -f $(Resolve-Path -Path ("$HomePath\*Documents")))
                } else {
                    Write-Verbose -Message ('$HomePath ''{0}'' does not appear to contain a [My ]Documents folder, so it''s not obviously a usable {1} path. Trying H:\' -f $HomePath, $HOME)
                    $HomePath = 'H:'
                }

                # Test again
                if (Test-Path -Path "$HomePath\*Documents") {
                    Write-Verbose -Message ('Confirmed {0} is available' -f $(Resolve-Path -Path ("$HomePath\*Documents")))
                    $myPSHome = Join-Path -Path $HomePath -ChildPath '*Documents\WindowsPowerShell' -Resolve
                } else {
                    Write-Warning -Message 'Failed to find a reliable $HOME path. Consider updating $HOME and trying again.'
                    break
                }
            } else {
                Write-Verbose -Message ('Determined {0} ($Env:HOMEDRIVE+$Env:HOMEPATH) is NOT available' -f ("$Env:HOMEDRIVE$Env:HOMEPATH"))
                $HomePath = $HOME
            }

            Write-Verbose -Message 'Testing if $HomePath is like SystemDrive'
            if ($HomePath -like "$Env:SystemDrive*") {
                Write-Warning -Message ('Environment derived $HomePath ''{0}'' is also on SystemDrive' -f $HomePath)
                #$myPSHome = Join-Path -Path $HomePath -ChildPath '*Documents\WindowsPowerShell' -Resolve
                Set-Variable -Name myPSHome -Value (Join-Path -Path $HomePath -ChildPath '*Documents\WindowsPowerShell' -Resolve) -Force -Scope Global
            } else {
                Write-Debug -Message ('Updating $HOME to {0}.' -f $HomePath)
                Set-Variable -Name HOME -Value (Resolve-Path $HomePath) -Force
                Write-Verbose -Message (' # SUCCESS: $HOME`: {0} is now distinct from SystemDrive.' -f $HOME) 
            }
        } else {
            # $HOME is NOT on the SystemDrive, so confirm it's available
            if (Test-Path -Path $HOME -ErrorAction Stop) {
                #$myPSHome = Join-Path -Path $HOME -ChildPath '*Documents\WindowsPowerShell' -Resolve
                Set-Variable -Name myPSHome -Value (Join-Path -Path $HOME -ChildPath '*Documents\WindowsPowerShell' -Resolve) -Force -Scope Global
            } else {
                write-output -InputObject ''
                Write-Warning -Message ' FYI: Failed to access $HOME; Defaulting to $env:USERPROFILE'
                write-output -InputObject ''
                $myPSHome = Join-Path -Path $env:USERPROFILE -ChildPath '*Documents\WindowsPowerShell' -Resolve
                Set-Variable -Name myPSHome -Value (Join-Path -Path $env:USERPROFILE -ChildPath '*Documents\WindowsPowerShell' -Resolve) -Force -Scope Global
                Write-Verbose -Message ('Updating $HOME to {0}.' -f $env:USERPROFILE)
                Set-Variable -Name HOME -Value (Resolve-Path $env:USERPROFILE) -Force
            }
        }
    } else {
        # Need to confirm / test this on non-windows OS
        #$myPSHome = Join-Path -Path $HOME -ChildPath '.config/powershell' -Resolve
        Set-Variable -Name myPSHome -Value (Join-Path -Path $HOME -ChildPath '.config/powershell' -Resolve) -Force -Scope Global
    }

    if (Test-Path -Path $myPSHome) {
        Write-Verbose -Message ('$myPSHome is {0}' -f $myPSHome)
        write-output -InputObject ''
        Write-Output -InputObject "PS .\> $((Push-Location -Path $myPSHome -PassThru | Select-Object -Property Path).Path)"
        write-output -InputObject ''
    } else {
        throw 'Failed to establish / locate path to $HOME\*Documents\WindowsPowerShell. Resolve and reload $PROFILE'
        break
    }

    #End Region

#Region ModulePath
    <# check and conditionally update/fix PSModulePath
        on Mac, default PSMODULEPATH (yes, it's case sensitive) is: $env:USERPROFILE/.local/share/powershell/Modules;;/usr/local/microsoft/powershell/Modules
    #>

    Write-Verbose -Message 'Checking $env:PSModulePath for user modules path ($myPSModulesPath)'
    if ($IsWindows) {
        $Private:SplitChar = ';'
        # Use local $HOME if GPO/UNC $HOME is not available
        if (-not (Get-Variable -Name HOME)) {
            Write-Verbose -Message 'Setting $HOME to $myPSHome'
            Set-Variable -Name HOME -Value $(Split-Path -Path (Split-Path -Path $myPSHome -Parent) -Parent)
        }

        #Define modules and scripts folders within user's PowerShell folder, creating the SubFolders if necessary
        $myPSModulesPath = (Join-Path -Path $myPSHome -ChildPath 'Modules')
        if (-not (Test-Path -Path $myPSModulesPath)) {
            New-Item -Path $myPSHome -ItemType Directory -Name 'Modules'
        }

        $myPSScriptsPath = (Join-Path -Path $myPSHome -ChildPath 'Scripts')
        if (-not (Test-Path -Path $myPSScriptsPath)) {
            New-Item -Path $myPSHome -ItemType Directory -Name 'Scripts'
        }

        $myPSLogPath = (Join-Path -Path $myPSHome -ChildPath 'log')
        if (-not (Test-Path -Path $myPSLogPath)) {
            New-Item -Path $myPSHome -ItemType Directory -Name 'log'
        }

    } else {
        $Private:SplitChar = ':'
        if (-not (Test-Path -Path $HOME)) {
            Write-Verbose -Message 'Setting $HOME to $myPSHome'
            Set-Variable -Name HOME -Value $(Split-Path -Path $myPSHome -Parent) -Force
        }

        $myPSModulesPath = (Join-Path -Path $HOME -ChildPath '.local/share/powershell/Modules') # OR /usr/local/share/powershell/Modules
        Set-Variable -Name myPSModulesPath -Value (Join-Path -Path $HOME -ChildPath '.local/share/powershell/Modules') -Force -Scope Global
        $myPSScriptsPath = (Join-Path -Path $HOME -ChildPath '.local/share/powershell/Scripts')
        Set-Variable -Name myPSScriptsPath -Value (Join-Path -Path $HOME -ChildPath '.local/share/powershell/Scripts') -Force -Scope Global
    }

    Write-Verbose -Message ('My PS Modules Path: {0}' -f $myPSModulesPath)

    Write-Debug -Message ('($myPSModulesPath -in @($env:PSMODULEPATH -split $Private:SplitChar) = {0}' -f ($myPSModulesPath -in @($env:PSMODULEPATH -split $Private:SplitChar)))
    if (($null -ne $myPSModulesPath) -and (-not ($myPSModulesPath -in @($env:PSMODULEPATH -split $Private:SplitChar)))) {
        # Improve to only conditionally modify 
        # $env:PSMODULEPATH = $myPSHome\Modules"; "$PSHome\Modules"; "${env:ProgramFiles(x86)}\WindowsPowerShell\Modules"; "$env:ProgramFiles\WindowsPowerShell\Modules") -join ';'
        Write-Verbose -Message ('Adding Modules Path: {0} to $env:PSMODULEPATH' -f $myPSModulesPath) -Verbose
        $env:PSMODULEPATH += "$Private:SplitChar$myPSModulesPath"

        # post-update cleanup
        if (Test-Path -Path $myPSScriptsPath) {
            & $myPSScriptsPath\Cleanup-ModulePath.ps1
            $env:PSMODULEPATH
        }
    }
#End Region ModulePath

Write-Verbose -Message 'Declaring function Get-CustomModule'
function Get-CustomModule {
    return Get-Module -ListAvailable | Where-Object -FilterScript {$PSItem.ModuleType -eq 'Script' -and $PSItem.Author -notlike 'Microsoft Corporation'}
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

<#
    # For intra-profile/bootstrap script flow Testing
    Write-Output -InputObject ''
    Start-Sleep -Seconds 3
#>