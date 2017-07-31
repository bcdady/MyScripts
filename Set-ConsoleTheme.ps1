#!/usr/local/bin/powershell
#Requires -Version 2 -module ConsoleTheme

[CmdletBinding()]
Param()
Set-StrictMode -Version latest

#Region MyScriptInfo
  Write-Verbose -Message '[Set-ConsoleTheme] Populating $MyScriptInfo'
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
  Write-Verbose -Message '[Set-ConsoleTheme] $MyScriptInfo populated'
#End Region

# dot-source script file containing Add-PATH and related helper functions
$RelativePath = Split-Path -Path (Resolve-Path -Path $MyScriptInfo.CommandPath -Relative) -Parent
#Write-Verbose -Message "Initializing $RelativePath\Edit-Path.ps1" -Verbose
#. $RelativePath\Edit-Path.ps1

Write-Verbose -Message 'Declaring Function Set-ConsoleTheme'
Function Set-ConsoleTheme {
    Write-Verbose -Message 'Setting ConsoleTheme'
    # if ($Env:PSEdit) {
    #     return $Env:PSEdit
    # }
    # else {
    # Write-Output -InputObject "Env:PSEdit is Undefined.`nRun Assert-PSEdit to declare or detect Path to available editor."
    # }

    Set-TerminalColor -Background MidnightBlue -Foreground SteelBlue
    
    Set-Font -FontName Consolas -FontSize 12
    
    Set-TerminalTitle
}