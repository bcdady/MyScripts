#!/usr/bin/env powershell
#!/usr/local/bin/powershell
#Requires -Version 3
#========================================
# NAME      : profile.ps1
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
    Write-Verbose -Message '[$PROFILE] Populating $MyScriptInfo'
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
    $MyScriptInfo = New-Object -TypeName PSObject -Property $properties
    Write-Verbose -Message '[$PROFILE] $MyScriptInfo populated'
#End Region

#Region Bootstrap
    # Moved HOME / MyPSHome, Modules, and Scripts variable determination to bootstrap script
    if (Test-Path -Path (Join-Path -Path (split-path -Path $MyScriptInfo.CommandPath) -ChildPath 'bootstrap.ps1')) {
        . (Join-Path -Path (split-path -Path $MyScriptInfo.CommandPath) -ChildPath 'bootstrap.ps1')
        if (Get-Variable -Name 'myPS*' -ValueOnly -ErrorAction Ignore) {
            Write-Output -InputObject ''
            Write-Output -InputObject 'My PowerShell Environment:'
            Get-Variable -Name 'myPS*' | Format-Table -AutoSize
        } else {
            throw ('Failed to bootstrap: {0}\bootstrap.ps1' -f $script:MyCommandPath)
        }
    } else {
        throw ('Failed to locate profile-prerequisite bootstrap script: {0}' -f (Join-Path -Path (split-path -Path $MyScriptInfo.CommandPath) -ChildPath 'bootstrap.ps1'))
    }
#End Region  
Write-Output -InputObject (" # Loading PowerShell `$Profile CurrentUserCurrentHost from {0} # " -f $MyScriptInfo.CommandPath)

Write-Debug -Message 'Detect -Verbose $VerbosePreference'
switch ($VerbosePreference) {
  Stop             { $IsVerbose = $True }
  Inquire          { $IsVerbose = $True }
  Continue         { $IsVerbose = $True }
  SilentlyContinue { $IsVerbose = $False }
  Default          { $IsVerbose = $False }
}
Write-Debug -Message ("`$VerbosePreference: {0} is {1}" -f $VerbosePreference, $IsVerbose)

Write-Verbose -Message 'Customizing Console window title and prompt'
# custom prompt function is provided within ProfilePal module
Import-Module -Name ProfilePal 
Set-ConsoleTitle

# Display execution policy, for convenience
Write-Output -InputObject 'PowerShell Execution Policy: '
Get-ExecutionPolicy -List | Format-Table -AutoSize

$Global:onServer = $false
$Global:onXAHost = $false
if ($hostOSCaption -like '*Windows Server*') {
  $Global:onServer = $true
}

if ($IsWindows -and (-not (Get-Variable -Name LearnPowerShell -Scope Global -ValueOnly -ErrorAction Ignore))) {
  # Learn PowerShell today ...
  # Thanks for this tip goes to: http://jdhitsolutions.com/blog/essential-powershell-resources/
  Write-Verbose -Message ' # selecting (2) random PowerShell cmdlet help to review #'
  
  Get-Command -Module Microsoft*, Cim*, PS*, ISE |
  Get-Random |
  Get-Help -ShowWindow

  Get-Random -Maximum (Get-Help -Name about_*) |
  Get-Help -ShowWindow
  [bool]$global:LearnPowerShell = $true
}

# Preset PSDefault Parameter Values 
# http://blogs.technet.com/b/heyscriptingguy/archive/2012/11/02/powertip-automatically-format-your-powershell-table.aspx
$PSDefaultParameterValues= @{
    'Format-Table:autosize' = $true
    'Format-Table:wrap'     = $true
    'Get-Help:Examples'     = $true
    'Get-Help:Online'       = $true
    'Install-Module:Scope'  = 'CurrentUser'
    'Enter-PSSession:Authentication'      = 'Credssp'
    'Enter-PSSession:Credential'          = {Get-Variable -Name my2acct -ErrorAction Ignore}
    'Enter-PSSession:EnableNetworkAccess' = $true
    'New-PSSession:Authentication'        = 'Credssp'
    'New-PSSession:Credential'            = {Get-Variable -Name my2acct -ErrorAction Ignore}
    'New-PSSession:EnableNetworkAccess'   = $true
}
