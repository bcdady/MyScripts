#!/usr/local/bin/powershell
#Requires -Version 2
[CmdletBinding()]
Param()
#Set-StrictMode -Version latest

# Ensure this script is dot-sourced, to get access to it''s contained functions

#Region MyScriptInfo
  Write-Verbose -Message '[Test-Registry] Populating $MyScriptInfo'
  $script:MyCommandName = $MyInvocation.MyCommand.Name
  $script:MyCommandPath = $MyInvocation.MyCommand.Path
  $script:MyCommandType = $MyInvocation.MyCommand.CommandType
  $script:MyCommandModule = $MyInvocation.MyCommand.Module
  $script:MyModuleName = $MyInvocation.MyCommand.ModuleName
  $script:MyCommandParameters = $MyInvocation.MyCommand.Parameters
  $script:MyParameterSets = $MyInvocation.MyCommand.ParameterSets
  $script:MyRemotingCapability = $MyInvocation.MyCommand.RemotingCapability
  $script:MyVisibility = $MyInvocation.MyCommand.Visibility

  if (($null -eq $script:MyCommandName) -or ($null -eq $script:MyCommandPath)) {
    # We didn't get a successful command / script name or path from $MyInvocation, so check with CallStack
    Write-Verbose -Message "Getting PSCallStack [`$CallStack = Get-PSCallStack]"
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
  Write-Verbose -Message '[Test-Registry] $MyScriptInfo populated'
#End Region

# Detect older versions of PowerShell and add in new automatic variables for more cross-platform consistency
if ($Host.Version.Major -le 5) {
  $Global:IsWindows = $true
  $Global:PSEdition = 'Windows'
}

# dot-source script file containing Add-PATH and related helper functions
#$RelativePath = Split-Path -Path (Resolve-Path -Path $MyScriptInfo.CommandPath) -Parent
#Write-Verbose -Message "Initializing .\Edit-Path.ps1"
#. $(Join-Path -Path (Split-Path -Path (Resolve-Path -Path $MyScriptInfo.CommandPath) -Parent) -Childpath 'Edit-Path.ps1')

<#
    GoToMeeting behavior in IE:

    https://support.logmeininc.com/gotomeeting/get-ready?c_prod=csp&c_name=g2m_home_download

    Registry files from laptop:
    S:\Infrastructure\Systems\Citrix\gotomeeting.reg

    Maybe need to "blow away" HKEY_CURRENT_USER\Software\Citrix\GoToMeeting ?
    -- appears to hang on to old meeting info
    UninstallString
#>

# 'HKCU:\Software\Citrix\GoToMeeting'

$CURegPath = @('HKCU:\Software\Classes\.gotomeeting','HKCU:\Software\Classes\citrixonline','HKCU:\Software\Classes\CitrixOnline.Collab','HKCU:\Software\Classes\CitrixOnline.Collab.GTM','HKCU:\Software\Classes\CitrixOnline.Launcher','HKCU:\Software\Classes\gotomeeting','HKCU:\Software\Classes\MIME\Database\Content Type\application/x-gotomeeting','HKCU:\Software\Microsoft\Internet Explorer\Low Rights\ElevationPolicy','HKCU:\Software\Microsoft\Internet Explorer\LowRegistry\DOMStorage\global.gotomeeting.com','HKCU:\Software\Microsoft\Internet Explorer\LowRegistry\DOMStorage\gotomeeting.com','HKCU:\Software\Microsoft\Internet Explorer\ProtocolExecute\citrixonline','HKCU:\Software\Microsoft\Internet Explorer\ProtocolExecute\gotomeeting','HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\GoToMeeting')
$LMRegPath = @('HKLM:\Software\Classes\.gotomeeting','HKLM:\Software\Classes\citrixonline','HKLM:\Software\Classes\CitrixOnline.Collab','HKLM:\Software\Classes\CitrixOnline.Collab\Shell','HKLM:\Software\Classes\CitrixOnline.Collab\Shell\Open','HKLM:\Software\Classes\CitrixOnline.Collab\Shell\Open\Command','HKLM:\Software\Classes\CitrixOnline.Launcher','HKLM:\Software\Classes\CitrixOnline.Launcher\Shell','HKLM:\Software\Classes\CitrixOnline.Launcher\Shell\Open','HKLM:\Software\Classes\CitrixOnline.Launcher\Shell\Open\Command','HKLM:\Software\Classes\citrixonline\Shell','HKLM:\Software\Classes\citrixonline\Shell\Open','HKLM:\Software\Classes\citrixonline\Shell\Open\Command','HKLM:\Software\Classes\gotomeeting','HKLM:\Software\Classes\gotomeeting\Shell','HKLM:\Software\Classes\gotomeeting\Shell\Open','HKLM:\Software\Classes\gotomeeting\Shell\Open\Command','HKLM:\Software\Classes\MIME\Database\Content Type\application/x-gotomeeting')

# Search-Registry is a command from the PowerShellCookbook module
#Search-Registry 'citrixonline' -ErrorAction SilentlyContinue | Select-Object -Property KeyName

Write-Verbose -Message 'Declaring Function Test-GTMUserKey'
Function Test-GTMUserKey {
    $CURegPath | ForEach-Object {
        if (Test-RegKey -Path $PSItem -Verbose) {
            Get-RegProperty -Path $PSItem
        }
        ""
        Start-Sleep -Seconds 1
    }
}

Write-Verbose -Message 'Declaring Function Test-GTMComputerKey'
Function Test-GTMComputerKey {
    $LMRegPath | ForEach-Object {
        Test-RegKey -Path $PSItem -Verbose
        ""
        Start-Sleep -Seconds 1
    }
}

Write-Verbose -Message 'Declaring Function Test-RegKey'
Function Test-RegKey {
    [CmdletBinding()]
    Param (
        [Parameter(Position=0)]
        [string]$Path
    )

    Write-Debug -Message "Parameter `$Path is '$Path'"
    # Transpose long form key names into PSDrive format
    if ($Path -like "HKEY_*") {
        $Path = $Path.Replace("HKEY_CURRENT_USER",'HKCU:')
        $Path = $Path.Replace("HKEY_LOCAL_MACHINE",'HKLM:')
    }
    Write-Verbose -Message "Test-Path -Path $Path"
    return Test-Path -Path $Path
}

Write-Verbose -Message 'Declaring Function Get-RegProperty'
Function Get-RegProperty {
    [CmdletBinding()]
    Param (
        [Parameter(Position=0)]
        [string]$Path
        ,
        [Parameter(Position=1)]
        [string]$Property
    )

    Write-Debug -Message "Parameter `$Path is '$Path'"
    # Transpose long form key names into PSDrive format
    if ($Path -like "HKEY_*") {
        $Path = $Path.Replace("HKEY_CURRENT_USER",'HKCU:')
        $Path = $Path.Replace("HKEY_LOCAL_MACHINE",'HKLM:')
    }

    Write-Verbose -Message "At Registry Key '$Path' ..."
    if ($Property) {
        Write-Verbose "Checking Property $Property"
        $Value = Get-ItemProperty -Path "$Path" -Name "$Property" -ErrorAction SilentlyContinue | Select-Object -Property "$Property" -ErrorAction SilentlyContinue
        if ($Value) {
            $Value = $Value."$Property"
        }
        Write-Verbose "Property is '$Value'"
    } else {

 = '(Default)'
         Write-Verbose "Enumerating all registry values in this key"
        $Value = Get-Item -Path $Path
    }
    return $Value
}

