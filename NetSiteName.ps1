#requires -Version 3 -Modules PSLogger, Sperry

<#
    Author: Bryan Dady
    Version: 1.0.3
    Version History: Created Get-NetSite function as an enhancement on the Get-IPAddress function
    2015/7/23 (1.0.3) : Add 10.92.x.x / 10.9n.x.x handling
    Purpose: Provide location/context information for a corporate network

#>

function Get-NetSite
{
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
    New-Variable -Name outputobj -Description 'Object to be returned by this function' -Scope Private
    Get-IPAddress | ForEach-Object -Process {
        switch -Regex ($PSItem.IPAddress) {
            ^10\.10\.\d+
            {
                $Private:SiteName = 'Helena'
                break
            }
            ^10\.20\.\d+
            {
                $Private:SiteName = 'Missoula - CoLo'
                break
            }
            ^10\.100\.92\.\d+
            {
                $Private:SiteName = 'Missoula - Great Northern'
                break
            }
            ^10\.100\.91\.\d+
            {
                $Private:SiteName = 'Missoula - Southgate'
                break
            }
            ^10\.100\.9\d\.\d+
            {
                $Private:SiteName = 'Missoula - Other'
                break
            }
            ^10\.100\.\d+
            {
                $Private:SiteName = 'Corporate'
                break
            }
            ^192\.168\.\d+
            {
                $Private:SiteName = 'Private NAT'
                break
            }
            Default
            {
                $Private:SiteName = 'Unrecognized'
                break
            }
        } # end switch

        $Private:properties = [ordered]@{
            'AdapterHost'        = 'Undefined'
            'AdapterDescription' = 'Undefined'
            'SiteName'           = 'Undefined'
            'IPAddress'          = 'Undefined'
            'Gateway'            = 'Undefined'
            'DNSServers'         = 'Undefined'
        }

        if ($Private:SiteName -eq 'Unrecognized')
        {
            Write-Log -Message "Connected to unrecognized or non-workplace network : $($PSItem.IPAddress)" -Function 'NetSiteName' -Verbose
        }
        else
        {
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

        $Private:RetObject = New-Object -TypeName PSObject -Property $properties

        return $RetObject
    } # end foreach
} # end function Get-NetSite
