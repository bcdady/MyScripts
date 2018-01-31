#!/usr/local/bin/powershell
#requires -Version 3 -Modules PSLogger, Sperry
#========================================
# NAME      : NetSiteName.ps1
# LANGUAGE  : Windows PowerShell
# AUTHOR    : Bryan Dady
# UPDATED   : 07/7/2017
# COMMENT   : Created Get-NetSite function as an enhancement on the Get-IPAddress function. Provide location/context information for a corporate network.
# HISTORY   : 2017/07/07 Endhanced script format/structure, such as this header block and #Region MyScriptInfo
# HISTORY   : 2015/7/23 (1.0.3) : Add 10.92.x.x / 10.9n.x.x handling
#========================================
[CmdletBinding()]
param ()
Set-StrictMode -Version latest

#Region MyScriptInfo
    Write-Verbose -Message '[NetSiteName] Populating $MyScriptInfo'
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
        $Private:CallStack      = Get-PSCallStack | Select-Object -First 1
        # $CallStack | Select Position, ScriptName, Command | format-list # FunctionName, ScriptLineNumber, Arguments, Location
        $Private:myScriptName   = $Private:CallStack.ScriptName
        $Private:myCommand      = $Private:CallStack.Command
        Write-Verbose -Message "`$ScriptName: $Private:myScriptName"
        Write-Verbose -Message "`$Command: $Private:myCommand"
        Write-Verbose -Message 'Assigning previously null MyCommand variables with CallStack values'
        $Private:MyCommandPath  = $Private:myScriptName
        $Private:MyCommandName  = $Private:myCommand
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
    Write-Verbose -Message '[NetSiteName] $MyScriptInfo populated'

    if ('Verbose' -in $PSBoundParameters.Keys) {
        Write-Verbose -Message 'Output Level is [Verbose]. $MyScriptInfo is:'
        $MyScriptInfo
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
            VERSION     :  1.0.0
            LAST UPDATED:  5/1/2015
            AUTHOR      :  Bryan Dady
        .INPUTS
            None
        .OUTPUTS
            Write-Log
    #>
    [CmdletBinding()]
    param ()
    
    Get-IPAddress | ForEach-Object -Process {
        # Is there a better way to make this a lookup, e.g. from an Array ... that could be referenced in JSON or CSV?
        switch -Regex ($PSItem.IPAddress) {
            ^10\.10\.\d+ {
                $Private:SiteName = 'Helena'
                break
            }
            ^10\.20\.\d+ {
                $Private:SiteName = 'Missoula - CoLo'
                break
            }
            ^10\.100\.92\.\d+ {
                $Private:SiteName = 'Missoula - Great Northern'
                break
            }
            ^10\.100\.91\.\d+ {
                $Private:SiteName = 'Missoula - Southgate'
                break
            }
            ^10\.100\.9\d\.\d+ {
                $Private:SiteName = 'Missoula - Other'
                break
            }
            ^10\.100\.\d+ {
                $Private:SiteName = 'Corporate'
                break
            }
            ^10\.100\.\d+ {
                $Private:SiteName = 'NCB - Chelan'
                break
            }
            ^10\.116\.1\.\d+ {
                $Private:SiteName = 'Private NAT'
                break
            }
            Default {
                $Private:SiteName = 'Unrecognized'
                #break
            }
        } # end switch

        # Define default return-object properties // Optimize New-Object invocation, based on Don Jones' recommendation: https://technet.microsoft.com/en-us/magazine/hh750381.aspx
        $Private:properties      = [ordered]@{
            'AdapterHost'        = 'Undefined'
            'AdapterDescription' = 'Undefined'
            'SiteName'           = 'Undefined'
            'IPAddress'          = 'Undefined'
            'Gateway'            = 'Undefined'
            'DNSServers'         = 'Undefined'
        }

        if ($Private:SiteName -eq 'Unrecognized') {
            Write-Log -Message "Connected to unrecognized or non-workplace network : $($PSItem.IPAddress)" -Function 'NetSiteName' -Verbose
        } else {
            Write-Log -Message "Connected to $env:USERDOMAIN - $SiteName" -Function 'NetSiteName'
        } # end if $SiteName

        #'Optimize New-Object invocation, based on Don Jones' recommendation: https://technet.microsoft.com/en-us/magazine/hh750381.aspx
        $Private:properties = [ordered]@{
            'AdapterHost'        = $PSItem.AdapterHost
            'AdapterDescription' = $PSItem.AdapterDescription
            'SiteName'           = $SiteName
            'IPAddress'          = $PSItem.IPAddress
            'Gateway'            = $PSItem.Gateway
            'DNSServers'         = $PSItem.DNSServers
        } # end properties

        $Private:RetObject = New-Object -TypeName PSObject -Property $Private:properties

        return $Private:RetObject
    } # end foreach
} # end function Get-NetSite
