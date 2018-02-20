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
Set-StrictMode -Off

# Set Verbose host output Preference :: $VerbosePreference = 'Inquire'

#Region MyScriptInfo
    Write-Verbose -Message '[CurrentUserAllHosts Profile] Populating $MyScriptInfo'
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
        $Private:CallStack = Get-PSCallStack | Select-Object -First 1
        # $Private:CallStack | Select Position, ScriptName, Command | format-list # FunctionName, ScriptLineNumber, Arguments, Location
        $Private:MyScriptName = $Private:CallStack.ScriptName
        $Private:MyCommand = $Private:CallStack.Command
        Write-Verbose -Message "`$ScriptName: $Private:MyScriptName"
        Write-Verbose -Message "`$Command: $Private:MyCommand"
        Write-Verbose -Message 'Assigning previously null MyCommand variables with CallStack values'
        $Private:MyCommandPath = $Private:MyScriptName
        $Private:MyCommandName = $Private:MyCommand
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
    Write-Verbose -Message '[CurrentUserAllHosts Profile] $MyScriptInfo populated'

    # Cleanup
    foreach ($var in $Private:properties.Keys) {
        Remove-Variable -Name ('My{0}' -f $var) -Force
    }

    $IsVerbose = $false
    if ('Verbose' -in $PSBoundParameters.Keys) {
        Write-Verbose -Message 'Output Level is [Verbose]. $MyScriptInfo is:'
        $IsVerbose = $true
        $Script:MyScriptInfo
    }
#End Region

Write-Output -InputObject ' # Loading PowerShell $Profile CurrentUserAllHosts #'
Write-Verbose -Message (' ... from {0} # ' -f $MyScriptInfo.CommandPath)

#Region Bootstrap
    # Moved HOME / MyPSHome, Modules, and Scripts variable determination to bootstrap script
    #Write-Debug -Message ('[bool](Get-Variable -Name myPSHome -ErrorAction Ignore) = {0}' -f [bool](Get-Variable -Name myPSHome -ErrorAction Ignore))
        
    #Write-Verbose -Message ' # This Session was previously bootstrapped #'
    #$PSBootStrap = (Join-Path -Path (split-path -Path $MyScriptInfo.CommandPath) -ChildPath 'bootstrap.ps1' -ErrorAction Ignore) 
    #Write-Debug -Message ('Test-Path -Path {0}: {1}' -f $PSBootStrap, (Test-Path -Path $PSBootStrap))

    # if (Get-Variable -Name myPSHome -ErrorAction Ignore) {
    #     Write-Verbose -Message ' # This Session was previously bootstrapped #'
    # } else {
    #     # Load/invoke bootstrap
    #     if (Test-Path -Path $PSBootStrap) {
    #         Write-Verbose -Message ('Dot-sourcing {0} at {1}' -f $PSBootStrap, (Get-Date))
    #         . $PSBootStrap
              . (Join-Path -Path (split-path -Path $MyScriptInfo.CommandPath) -ChildPath 'bootstrap.ps1' -ErrorAction Stop) 
    
    #         if (Get-Variable -Name 'myPS*' -ValueOnly -ErrorAction Ignore) {
    #             Write-Output -InputObject ''
    #             Write-Output -InputObject 'My PowerShell Environment:'
    #             Get-Variable -Name 'myPS*' | Format-Table
    #         } else {
    #             Write-Warning -Message ('Failed to enumerate My PowerShell Environment as should have been initialized by bootstrap script: {0}' -f $PSBootStrap)
    #         }
    #     } else {
    #         throw ('Failed to bootstrap via {0}' -f $PSBootStrap)
    #     }
    # }
#End Region  

# Define custom prompt format:
Write-Verbose -Message 'Defining function prompt'
function prompt {
    # Set-ConsoleTitle -verbose
    $PriorErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'

    $IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')
    if($IsAdmin) {$AdminPrompt = '[ADMIN]:'} else {$AdminPrompt = ''}
    if($PSDebugContext) {$DebugPrompt = '[DEBUG]:'} else {$DebugPrompt = ''}
    if($PSConsoleFile){$PSCPrompt = "[PSConsoleFile: $PSConsoleFile]"} else {$PSCPrompt = ''}

    $ErrorActionPreference = $PriorErrorActionPreference

    if($NestedPromptLevel -ge 1){ $PromptLevel = 'PS .\> >' } else { $PromptLevel = 'PS .\>'}

    ( "[{0} @ {1}]`n{2}{3}{4}{5}" -f $env:ComputerName, $pwd.Path, $AdminPrompt, $PSCPrompt, $DebugPrompt, $PromptLevel)
}

Write-Debug -Message 'Detect -Verbose $VerbosePreference'
switch ($VerbosePreference) {
    Stop             { $IsVerbose = $True }
    Inquire          { $IsVerbose = $True }
    Continue         { $IsVerbose = $True }
    SilentlyContinue { $IsVerbose = $False }
    Default          { $IsVerbose = $False }
}
Write-Debug -Message ('$VerbosePreference: {0} is {1}' -f $VerbosePreference, $IsVerbose)

if (get-module -Name ProfilePal) {
    Write-Verbose -Message 'ProfilePal Module imported'
} else {
    Write-Verbose -Message 'Customizing Window Title'
    # custom prompt function is provided within ProfilePal module
    Import-Module -Name ProfilePal 
    Write-Verbose -Message 'ProfilePal Module imported'

    Write-Verbose -Message 'Set-ConsoleTitle'
    Set-ConsoleTitle
}

# Display execution policy, for convenience
Write-Output -InputObject 'PowerShell Execution Policy: '
Get-ExecutionPolicy -List | Format-Table -AutoSize

$Global:onServer = $false
$Global:onXAHost = $false
if ($hostOSCaption -like '*Windows Server*') {
  Set-Variable -Name onServer -Value $true -Scope Global -PassThru
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

    Set-Variable -Name LearnPowerShell -Value $true -Scope Global
}
Write-Output -InputObject ''

# Preset PSDefault Parameter Values 
# http://blogs.technet.com/b/heyscriptingguy/archive/2012/11/02/powertip-automatically-format-your-powershell-table.aspx
$PSDefaultParameterValues= @{
    'Format-Table:AutoSize' = $true
    'Format-Table:Wrap'     = $true
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

Write-Output -InputObject ' # End of PowerShell $Profile CurrentUserAllHosts #'

<#
    # For intra-profile/bootstrap script flow Testing
    Write-Output -InputObject ''
    Start-Sleep -Seconds 3
#>