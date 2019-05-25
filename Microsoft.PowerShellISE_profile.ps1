#!/usr/local/bin/powershell
#Requires -Version 3
#========================================
# NAME      : PowerShellISE_profile.ps1
# LANGUAGE  : Windows PowerShell
# AUTHOR    : Bryan Dady
# UPDATED   : 11/28/2017
# COMMENT   : Originally created by New-Profile cmdlet in ProfilePal Module; modified for ps-core compatibility (use on Mac) by @bcdady 2016-09-27
# ~/.config/powershell/Microsoft.PowerShell_profile.ps1
#========================================
[CmdletBinding()]
param ()
Set-StrictMode -Version latest

#Region MyScriptInfo
    Write-Verbose -Message '[ISE_PROFILE] Populating $MyScriptInfo'
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
        Write-Verbose -Message ('$ScriptName: {0}' -f $script:myScriptName)
        Write-Verbose -Message ('`$Command: {0}' -f $script:myCommand)
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
    $MyScriptInfo = New-Object -TypeName PSObject -Property $properties
    Write-Verbose -Message '[ISE_PROFILE] $MyScriptInfo populated'
#End Region

Write-Output -InputObject (' # Loading PowerShell $Profile CurrentUserCurrentHost (ISE) from {0} #' -f $MyScriptInfo.CommandPath)

# Moved HOME / MyPSHome, Modules, and Scripts variable determination to shared bootstrap.ps1, invoked via profile.ps1
<#
    if (Test-Path -Path (Join-Path -Path (split-path -Path $MyInvocation.MyCommand.Path) -ChildPath 'bootstrap.ps1')) {
    . (Join-Path -Path (split-path -Path $MyInvocation.MyCommand.Path) -ChildPath 'bootstrap.ps1')
    if (Get-Variable -Name 'myPS*' -ValueOnly -ErrorAction Ignore) {
        Write-Output -InputObject 'My PowerShell Environment'
        Get-Variable -Name 'myPS*' | Format-Table -AutoSize
    } else {
        throw "Failed to bootstrap: $(Join-Path -Path (split-path -Path $MyInvocation.MyCommand.Path) -ChildPath 'bootstrap.ps1')"
    }
    } else {
    throw "Failed to locate profile-prerequisite bootstrap script: $(Join-Path -Path (split-path -Path $MyInvocation.MyCommand.Path) -ChildPath 'bootstrap.ps1')"
    }

    Write-Output -InputObject 'PowerShell Execution Policy:'
    Get-ExecutionPolicy -List | Format-Table -AutoSize
#>

# ISERegex
#write-output -InputObject ' # loading ISERegex # '
#Start-ISERegex

# ShowDSCResource Add-On
Write-Verbose -Message ' # loading Show-DscResource Module #'
Import-Module -Name $myPSModulesPath\ShowDscResource\ShowDscResourceModule.psd1 -PassThru | Format-Table -AutoSize
& Install-DscResourceAddOn -Verbose

Start-Sleep -Seconds 1
Write-Verbose -Message ' # Checking ISESteroids license #'
if (-not [bool](Get-ChildItem -Path "$env:APPDATA\ISESteroids\License" -Name -Filter 'ISESteroids_Professional.license' -File)) {
  copy-item -Path R:\IT\repo\DSC\ISESteroids_Professional.license -Destination "$env:APPDATA\ISESteroids\License"
  #Write-Warning -Message 'ISESteroids license file not found. Please contact Bryan Dady.'
  #Add-SteroidsLicense -Path R:\IT\repo\DSC\ISESteroids_Professional.license
}

# ISESteroids
Write-Output -InputObject ' # Loading ISESteroids [Start-Steroids] #'
Start-Steroids
