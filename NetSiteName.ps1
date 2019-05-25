#requires -Version 2
<#
    Author  : Bryan Dady
    Version : 1.0.5
    Purpose : Provide location/context information for a corporate network
    History : Created Get-NetSite function as an enhancement on the Get-IPAddress function
        2018/11/21 (1.0.5) : Update to work on Win10 with WindowsPowerShell 5.1
        2017/07/07 (1.0.4) : Enhanced script format/structure, such as this header block and #Region MyScriptInfo
        2015/07/23 (1.0.3) : Add 10.92.x.x / 10.9n.x.x handling to Get-NetSite IPAddress switch block
#>
#========================================
[CmdletBinding()]
param ()
Set-StrictMode -Version latest

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
    Write-Verbose -Message ('[{0}] Populating $MyScriptInfo' -f $MyInvocation.MyCommand.Name)
    $MyCommandName        = $MyInvocation.MyCommand.Name
    $MyCommandPath        = $MyInvocation.MyCommand.Path
    $MyCommandType        = $MyInvocation.MyCommand.CommandType
    $MyCommandModule      = $MyInvocation.MyCommand.Module
    $MyModuleName         = $MyInvocation.MyCommand.ModuleName
    $MyCommandParameters  = $MyInvocation.MyCommand.Parameters
    $MyParameterSets      = $MyInvocation.MyCommand.ParameterSets
    $MyRemotingCapability = $MyInvocation.MyCommand.RemotingCapability
    $MyVisibility         = $MyInvocation.MyCommand.Visibility

    if (($null -eq $MyCommandName) -or ($null -eq $MyCommandPath)) {
        # We didn't get a successful command / script name or path from $MyInvocation, so check with CallStack
        Write-Verbose -Message 'Getting PSCallStack [$CallStack = Get-PSCallStack]'
        $CallStack      = Get-PSCallStack | Select-Object -First 1
        # $CallStack | Select Position, ScriptName, Command | format-list # FunctionName, ScriptLineNumber, Arguments, Location
        $myScriptName   = $CallStack.ScriptName
        $myCommand      = $CallStack.Command
        Write-Verbose -Message ('$ScriptName: {0}' -f $myScriptName)
        Write-Verbose -Message ('$Command: {0}' -f $myCommand)
        Write-Verbose -Message 'Assigning previously null MyCommand variables with CallStack values'
        $MyCommandPath  = $myScriptName
        $MyCommandName  = $myCommand
    }

    #'Optimize New-Object invocation, based on Don Jones' recommendation: https://technet.microsoft.com/en-us/magazine/hh750381.aspx
    $properties = [ordered]@{
        'CommandName'        = $MyCommandName
        'CommandPath'        = $MyCommandPath
        'CommandType'        = $MyCommandType
        'CommandModule'      = $MyCommandModule
        'ModuleName'         = $MyModuleName
        'CommandParameters'  = $MyCommandParameters.Keys
        'ParameterSets'      = $MyParameterSets
        'RemotingCapability' = $MyRemotingCapability
        'Visibility'         = $MyVisibility
    }
    $MyScriptInfo = New-Object -TypeName PSObject -Property $properties
    Write-Verbose -Message ('[{0}] $MyScriptInfo populated' -f $MyInvocation.MyCommand.Name)

    # Cleanup
    foreach ($var in $properties.Keys) {
        Remove-Variable -Name ('My{0}' -f $var) -Force
    }
    Remove-Variable -Name properties
    Remove-Variable -Name var

    if ($IsVerbose) {
        Write-Verbose -Message '$MyScriptInfo:'
        $Script:MyScriptInfo
    }
#End Region

Write-Verbose -Message 'Declaring Function Get-NetSite'
 function Get-NetSite {
    <#
        .SYNOPSIS
            Returns a custom object with properties related to location on a corporate network, and basic DHCP info, collected from Get-IPAddress function.
        .DESCRIPTION
            Using the IP Address, determines the physical site/location that address is related to
        .EXAMPLE
            PS C:\> Get-IPAddress
            Get-NetSite

            SiteName           : Unrecognized
            AdapterHost        : ComputerName
            Gateway            : {192.168.1.11}
            IPAddress          : {192.168.1.106}
            DNSServers         : {192.168.0.1, 208.67.220.220, 208.67.222.222}
            AdapterDescription : Intel(R) Wireless-N 7260
        .EXAMPLE
            PS C:\> Get-NetSite.IPAddress
            # Returns only the IP Address(es) of DHCP enabled adapters, as a string
            10.10.101.123
        .NOTES
            NAME        :  Get-NetSite
            VERSION     :  1.0.4
            LAST UPDATED:  11/21/2018
            AUTHOR      :  Bryan Dady
        .INPUTS
            None
        .OUTPUTS
            Write-Log
    #>
    New-Variable -Name outputobj -Description 'Object to be returned by this function' -Scope Private

    if (Get-Command -Name Get-NetIPAddress) {
        $IPConfig = Get-NetIPAddress -AddressState Preferred -PrefixOrigin Dhcp | Get-NetIPConfiguration -Verbose:$false -Detailed
        $Private:ComputerName = $IPConfig.ComputerName
        $Private:Description  = ('{0}: {1} (connected to {2})' -f $IPConfig.InterfaceAlias, $IPConfig.InterfaceDescription, $IPConfig.NetProfile.Name)
        $Private:IPAddress    = $IPConfig.IPv4Address.IPAddress
        $Private:Gateway      = $IPConfig.IPv4DefaultGateway.NextHop
        $Private:DNSServers   = $IPConfig.DNSServer.ServerAddresses | where {$_ -match "\."}
    } else {
        IPConfig = Get-CimInstance -ClassName Win32_NetworkAdapterConfiguration -Filter 'IpEnabled = True'
        $Private:ComputerName  = $IPConfig.PSComputerName
        $Private:Description   = $IPConfig.Description
        $Private:IPAddress     = $IPConfig.IPAddress
        $Private:Gateway       = $IPConfig.DefaultIPGateway
        $Private:DNSServers    = $IPConfig.DNSServerSearchOrder
    }

    $Private:IPAddress | ForEach-Object -Process {
        switch -Regex ($PSItem) {
            ^10\.\d+\.\d+ {
                $Private:SiteName = 'Private NAT'
                break
            }
            ^192\.168\\d+\.\d+ {
                $Private:SiteName = 'Private NAT'
                break
            }
            Default {
                $Private:SiteName = 'Undefined'
                # break
            }
        } # end switch

        if ($Private:SiteName -eq 'Undefined') {
            ('Connected to unrecognized or non-workplace network : {0}' -f $Private:IPAddress) # -Function $MyInvocation.MyCommand.Name -Debug
        } else {
            ('Connected to {0} - {1}' -f $Env:USERDOMAIN, $Private:SiteName)
            #Write-Log -Message "Connected to $Env:USERDOMAIN - $SiteName" -Function $MyInvocation.MyCommand.Name
        } # end if $SiteName

            #'Optimize New-Object invocation, based on Don Jones' recommendation: https://technet.microsoft.com/en-us/magazine/hh750381.aspx
            $Private:properties = [ordered]@{
                'ComputerName'  = $Private:ComputerName
                'Description'   = $Private:Description
                'SiteName'      = $Private:SiteName
                'IPAddress'     = $Private:IPAddress
                'Gateway'       = $Private:Gateway
                'DNSServers'    = $Private:DNSServers
            }

        $Private:RetObject = New-Object -TypeName PSObject -Property $Private:properties

        return $Private:RetObject
    } # end foreach
} # end function Get-NetSite