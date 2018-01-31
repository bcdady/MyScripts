#!/usr/local/bin/powershell
#Requires -Version 3
#========================================
# NAME      : Bootstrap.ps1
# LANGUAGE  : Windows PowerShell
# AUTHOR    : Bryan Dady
# UPDATED   : 11/21/2017
# COMMENT   : To be used / invoked from a PowerShell profile script, to check for and use a network share (UNC) based $HOME, such as from a domain server
#========================================
[CmdletBinding()]
param()
Set-StrictMode -Version latest

#Region MyScriptInfo
    Write-Verbose -Message '[Bootstrap] Populating $MyScriptInfo'
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
        Write-Verbose -Message 'Getting PSCallStack [$CallStack = Get-PSCallStack]'
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
    Write-Verbose -Message '[Bootstrap] $MyScriptInfo populated'
#End Region

Write-Output -InputObject (' # Initiating PowerShell Environment Bootstrap from {0} # ' -f $MyScriptInfo.CommandPath)

# Detect older versions of PowerShell and add in new automatic variables for cross-platform consistency
if ($Host.Version.Major -le 5) {
    $Global:IsWindows = $true
    $Global:PSEdition = 'Windows'
}

if ($IsWindows) {
    $hostOS = 'Windows'
    $hostOSCaption = $((Get-CimInstance -ClassName Win32_OperatingSystem -Property Caption).Caption) -replace 'Microsoft ', ''
    # Check admin rights / role; same approach as Test-LocalAdmin function in Sperry module
    $IsAdmin = (([security.principal.windowsprincipal] [security.principal.windowsidentity]::GetCurrent()).isinrole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
}

if ((Get-Variable -Name IsLinux -ErrorAction Ignore) -eq $true) {
    $hostOS = 'Linux'
    $hostOSCaption = $hostOS
    # Check admin rights / role; same approach as Test-LocalAdmin function in Sperry module
    #$IsAdmin = ... ?
} 

if ((Get-Variable -Name IsOSX -ErrorAction Ignore) -eq $true) { 
    $hostOS = 'OSX'
    $hostOSCaption = $hostOS
    # Check admin / root rights / role
    #$IsAdmin = ... ?
} 

Write-Output -InputObject " # $ShellId $($Host.version.toString().substring(0,3)) $PSEdition on $hostOSCaption - $env:ComputerName #"

Write-Verbose -Message ('Setting environment HostOS to {0}' -f $hostOS)
$env:HostOS = $hostOS

$Global:onServer = $false
$Global:onXAHost = $false
if ($hostOSCaption -like '*Windows Server*') {
    $Global:onServer = $true
}

<#
    Get-Variable -Name Is* -Exclude ISERecent | Format-Table -AutoSize
        Name                           Value
        ----                           -----
        IsAdmin                        False
        IsCoreCLR                      True
        IsLinux                        False
        IsOSX                          True
        IsWindows                      False
#>

# Derive full path to user's $HOME and PowerShell folders
if ($IsWindows) {
    Write-Verbose -Message 'Checking if $HOME is on the Windows SystemDrive'
    # If $HOME is on the SystemDrive, then it's not the right $HOME we're looking for
    if ($Global:HOME -like "$Env:SystemDrive*") {
        Write-Warning -Message ('$HOME ''{0}'' is on SystemDrive. Looking for another possible HOME path' -f $HOME)
          # Try to figure out where the non-local-system $HOME is
          $HomePath = Join-Path -Path $Env:HOMEDRIVE -ChildPath $Env:HOMEPATH -Resolve

          if (Test-Path -Path "$HomePath\*Documents") {
            Write-Verbose -Message ('Confirmed {0} is available' -f $(Resolve-Path -Path ("$HomePath\*Documents")))
          } else {
            Write-Verbose -Message ('$HomePath ''{0}'' does not appear to contain a [My ]Documents folder, so it''s not obviously a usable {1} path. Trying H:\' -f $HomePath, $HOME)
            $HomePath = 'H:'
          }

          # Test again
          if (Test-Path -Path "$HomePath\*Documents") {
            Write-Verbose -Message ('Confirmed {0} is available' -f $(Resolve-Path -Path ("$HomePath\*Documents")))
        } else {
            Write-Warning -Message 'Failed to find a reliable $HOME path. Consider updating $HOME and trying again.'
            break
        }

        Write-Verbose -Message "Testing if `$HomePath  is like SystemDrive"
        if ($HomePath -like "$Env:SystemDrive*") {
            Write-Warning -Message ('Environment derived $HomePath ''{0}'' is also on SystemDrive' -f $HomePath)
        } else {
            Write-Verbose -Message ('Updating $HOME to {0}.' -f $HomePath)
            Set-Variable -Name HOME -Value (Resolve-Path $HomePath) -Force -PassThru
            Write-Verbose -Message (' # SUCCESS: $HOME`: {0} is now distinct from SystemDrive.' -f $HOME) 
        }
    }
    $myPSHome = Join-Path -Path $HOME -ChildPath '*\WindowsPowerShell' -Resolve    
} else {
    # Need to confirm / test this on non-windows OS
    try {
        $myPSHome = Join-Path -Path $HOME -ChildPath '*\WindowsPowerShell' -Resolve
    }
    catch {
        throw 'Failed to establish / locate path to $HOME\*\WindowsPowerShell. Resolve and reload $PROFILE'
        break
    }
}

Write-Verbose -Message ('$myPSHome is {0}' -f $myPSHome)
Write-Output -InputObject "PS .\> $((Push-Location -Path $myPSHome -PassThru | Select-Object -Property Path).Path)"

#Region ModulePath
    <# check and conditionally update/fix PSModulePath
        on Mac, default PSMODULEPATH (yes, it's case sensitive) is: $env:USERPROFILE/.local/share/powershell/Modules;;/usr/local/microsoft/powershell/Modules
    #>

    Write-Verbose -Message 'Checking $env:PSModulePath for user modules path ($myPSModulesPath)'
    if ($IsWindows) {
        $splitChar = ';'
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
    } else {
        $splitChar = ':'
        if (-not (Test-Path -Path $HOME)) {
            Write-Verbose -Message 'Setting $HOME to $myPSHome'
            Set-Variable -Name HOME -Value $(Split-Path -Path $myPSHome -Parent) -Force
        }

        $myPSModulesPath = (Join-Path -Path $HOME -ChildPath '.local/share/powershell/Modules') # OR /usr/local/share/powershell/Modules
        $myPSScriptsPath = (Join-Path -Path $HOME -ChildPath '.local/share/powershell/Scripts')
    }

    Write-Verbose -Message ('My PS Modules Path: {0}' -f $myPSModulesPath)
    Write-Verbose -Message ('My PS Scripts Path: {0}' -f $myPSScriptsPath)

    Write-Debug -Message "($myPSModulesPath -in @(`$env:PSMODULEPATH -split $splitChar)"
    Write-Debug -Message ($myPSModulesPath -in @($env:PSMODULEPATH -split $splitChar))
    if (($null -ne $myPSModulesPath) -and (-not ($myPSModulesPath -in @($env:PSMODULEPATH -split $splitChar)))) {
        # Improve to only conditionally modify 
        # $env:PSMODULEPATH = $myPSHome\Modules"; "$PSHome\Modules"; "${env:ProgramFiles(x86)}\WindowsPowerShell\Modules"; "$env:ProgramFiles\WindowsPowerShell\Modules") -join ';'
        Write-Verbose -Message ('Adding Modules Path: {0} to $env:PSMODULEPATH' -f $myPSModulesPath) -Verbose
        $env:PSMODULEPATH += "$splitChar$myPSModulesPath"

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
write-output -InputObject ' # To enumerate available Custom Modules, run: #'
write-output -InputObject '   # Get-CustomModule | Select-Object -Property Name, Description'

write-output -InputObject '   # To view additional available modules, run: Get-Module -ListAvailable'
Write-Output -InputObject '   # To view cmdlets available in a given module, run:'
Write-Output -InputObject '   #  Get-Command -Module <ModuleName>'

Write-Output -InputObject "`n # PowerShell Environment Bootstrap Complete #`n"

