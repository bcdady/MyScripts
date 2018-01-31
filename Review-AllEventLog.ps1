#!/usr/local/bin/powershell
#Requires -Version 2
[CmdletBinding()]
Param()
#Set-StrictMode -Version latest

# Ensure this script is dot-sourced, to get access to it''s contained functions

#Region MyScriptInfo
  Write-Verbose -Message '[Review-AllEventLog] Populating $MyScriptInfo'
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
  Write-Verbose -Message '[Review-AllEventLog] $MyScriptInfo populated'
#End Region

Write-Verbose -Message 'Declaring Function Review-AllEventLog'
function Review-AllEventLog {
    [CmdletBinding()]
    Param(
        # Specify advanced EventType filter options
        [Parameter(Position=0)]
        [ValidateSet('All', 'Information', 'Warning', 'Error', 'ExcludeInformation')]
        [String]
        $EventType = 'ExcludeInformation'
        ,
        # Specify advanced EventLog selection options
        [Parameter(Position=1)]
        [ValidateSet('All', 'Common', 'System', 'Security', 'Application','Windows PowerShell')]
        [String]
        $EventType = 'Common'

    )
    Write-Verbose -Message "Getting EventLog entries with EventType: $EventType"
    if ($Env:PSEdit) {
        return $Env:PSEdit
    }
    # Get-ChildItem Env:PSEdit -ErrorAction SilentlyContinue | Format-List
    #if (!$?) {
    else {
        Write-Output -InputObject "Env:PSEdit is Undefined.`nRun Assert-PSEdit to declare or detect Path to available editor."
    }
}

New-Alias -Name psedit -Value Review-AllEventLog -Scope Global -Force

# Conditionally restore this New-Alias invocation, with a check for 'VS Code' in Env:PATH
New-Alias -Name Code -Value Review-AllEventLog -Scope Global -Force
