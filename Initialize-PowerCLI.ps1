#!/usr/local/bin/powershell
#Requires -Version 3
#========================================
# NAME      : Initialize-PowerCLI.ps1
# LANGUAGE  : Windows PowerShell
# AUTHOR    : Bryan Dady
# UPDATED   : 06/21/2017
# COMMENT   : function to enter PowerCLI environemtn / context, just as though through the PowerCLI shortcut
#========================================
[CmdletBinding()]
param()
Set-StrictMode -Version latest

#Region MyScriptInfo
  Write-Verbose -Message '[PowerCLI] Populating $MyScriptInfo'
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
    Write-Verbose -Message '[PowerCLI] $MyScriptInfo populated'
#End Region

Write-Verbose -Message 'Declaring function Initialize-PowerCLIEnvironment'
function Initialize-PowerCLIEnvironment {
    # If PowerCLI snapin / modules are not loaded, then start Initialize-PowerCLIEnvironment.ps1
    # Check if the package is installed, and get it's path
    $PowerCLI_Path = Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'VMware\*\vSphere PowerCLI'
#    $PowerCLI_Path = Join-Path -Path ${env:ProgramFiles(x86)} -ChildPath 'VMware\Infrastructure\vSphere PowerCLI' -Resolve
    if (Test-Path -Path $PowerCLI_Path) {
        $PowerCLI_Path = Resolve-Path -Path $PowerCLI_Path
        if (Get-Command -Name Get-PowerCLIVersion -ErrorAction SilentlyContinue) {
            "PowerCli version:"
            Get-PowerCLIVersion
        } else {
            if (Join-Path -Path $PowerCLI_Path -ChildPath 'Scripts\Initialize-PowerCLIEnvironment.ps1' -Resolve) {
                write-output ' # Initialize-PowerCLIEnvironment #'
                & "$PowerCLI_Path\Scripts\Initialize-PowerCLIEnvironment.ps1"
            } else {
                Write-Warning 'Found PowerCLI path/folder, but failed to load Initialize-PowerCLIEnvironment.ps1'
            }
        }
    }
}