#!/usr/local/bin/pwsh
#Requires -Version 3
#========================================
# NAME      : Microsoft.PowerShell_profile.ps1
# LANGUAGE  : Microsoft PowerShell
# PowerShell $Profile
# Created by New-Profile function of ProfilePal module
# For more information, see https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_profiles
#========================================
[CmdletBinding()]
param ()
Set-StrictMode -Version latest

# -Optional- Specify custom font colors
# Uncomment the following if-block to tweak the colors of your console; the 'if' statement is to make sure we leave the ISE host alone

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
    Write-Verbose -Message '[CurrentUserCurrentHost Profile] Populating $MyScriptInfo'
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
        $Private:CallStack        = Get-PSCallStack | Select-Object -First 1
        $Private:MyScriptName     = $Private:CallStack.ScriptName
        $Private:MyCommand        = $Private:CallStack.Command
        Write-Verbose -Message ('$MyScriptName: {0}' -f $Private:MyScriptName)
        Write-Verbose -Message ('$MyCommand: {0}' -f $Private:MyCommand)
        Write-Verbose -Message 'Assigning previously null MyCommand variables with CallStack values'
        $Private:MyCommandPath    = $Private:MyScriptName
        $Private:MyCommandName    = $Private:MyCommand
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
    Write-Verbose -Message '[CurrentUserCurrentHost Profile] $MyScriptInfo populated'

    # Cleanup
    foreach ($var in $Private:properties.Keys) {
        Remove-Variable -Name ('My{0}' -f $var) -Force
    }

    if ($IsVerbose) {
        Write-Verbose -Message '$MyScriptInfo:'
        $Script:MyScriptInfo
    }
#End Region

Write-Verbose -Message (' # {0} #' -f $MyScriptInfo.CommandPath)

if ($IsVerbose) {Write-Output -InputObject ''}

Write-Verbose -Message 'Defining function Get-WiFiprofile'
Function Get-WiFiprofile {
    # Make a list with all WiFi SSID's and passwords stored locally on Windows OS.
    # copied from https://pastebin.com/raw/8tf7B2wZ, via https://blogs.technet.microsoft.com/heyscriptingguy/2015/11/23/get-wireless-network-ssid-and-password-with-powershell/

    $output = netsh.exe wlan show profiles
    $profileRows = $output | Select-String -Pattern 'All User Profile'
    $profileNames = New-Object System.Collections.ArrayList

    #for each profile name get the SSID and password
    for($i = 0; $i -lt $profileRows.Count; $i++){
        $profileName = ($profileRows[$i] -split ":")[-1].Trim()

        $profileOutput = netsh.exe wlan show profiles name="$profileName" key=clear

        $SSIDSearchResult = $profileOutput| Select-String -Pattern 'SSID Name'
        $profileSSID = ($SSIDSearchResult -split ":")[-1].Trim() -replace '"'

        $passwordSearchResult = $profileOutput| Select-String -Pattern 'Key Content'
        if($passwordSearchResult){
            $profilePw = ($passwordSearchResult -split ":")[-1].Trim()
        } else {
            $profilePw = ''
        }
        # The order in which netsh.exe wlan show profiles return results reflect their priority
        # in the Windows Settings e.g. "Manage Known Networks"
        # so we add a priority integer via $i+1

        $networkObject = New-Object -TypeName psobject -Property @{
            ProfileName = $profileName
            SSID        = $profileSSID
            Password    = $profilePw
            Priority    = $i+1
        }
        # use $null = to avoid a new counter-per-line-per $networkObject appearing on the console
        $null = $profileNames.Add($networkObject)
    }

    return $profileNames | Sort-Object -Property Priority,ProfileName # | Select-Object ProfileName, SSID, Password

}

Write-Verbose -Message 'Defining function Set-WiFiprofile'
Function Set-WiFiprofile {
    param(
        [Alias('adapter')]
        [string]$interface = 'Wi-Fi',
        [Parameter(
        ValueFromPipeline=$True,
        ValueFromPipelineByPropertyName=$True,
        HelpMessage='Help Message for Mandatory Parameter.')]
        [Alias('ParameterAlias')]
        [ValidateNotNullOrEmpty()]
        [string]$SSID
        ,
        [Alias('order')]
        [int16]$Priority = 1
    )

    ('netsh.exe wlan set profileorder name="{0}" interface="{1}" priority={2}' -f $SSID, $interface, $Priority)
    netsh.exe wlan set profileorder name="$SSID" interface="$interface" priority=$Priority
}