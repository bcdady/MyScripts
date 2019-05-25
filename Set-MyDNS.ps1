#Requires -Version 3 -PSEdition Desktop
#========================================
# NAME      : Set-MyDNS.ps1
# LANGUAGE  : Windows PowerShell
# AUTHOR    : Bryan Dady
# VERSION   : 1.0.1
# UPDATED   : 04/01/2019 - Add Neustar UltraDNS 'Family Secure' servers to supported list
# COMMENT   : Set (or reset) the DNS configuration for my local network adapter (e.g. Wi-Fi).
#             This is intended to make alternating from well-known DNS service providers (like CloudFlare 1.1.1.1, OpenDNS, etc.) and DHCP defaults.
#========================================
[CmdletBinding()]
Param()
#Set-StrictMode -Version latest

Write-Verbose -Message 'Importing function Get-MyDNS'
function Get-MyDNS {
    [CmdletBinding()]
    Param (
        [Parameter(Position=0,  ValueFromPipeline, ValueFromPipelineByPropertyName)]
        #ParameterSetName='ByIndex',
        [ValidateScript({
            $PSItem -in (Get-NetAdapter | Select-Object -ExpandProperty ifIndex)
        })]
        [Alias('ifIndex')]
        [Int]
        $InterfaceIndex,
        # default if $false, without this set, the -Physical parameter is included for Get-NetAdapter
        [switch]
        $IncludeVirtual,
        [ValidateSet('Up','Down')]
        [String]
        $Status = 'Up'
    )
    DynamicParam {

        # Set the dynamic parameters' name
        $ParameterName = 'Name'

        # Create the dictionary
        $RuntimeParameterDictionary = New-Object System.Management.Automation.RuntimeDefinedParameterDictionary

        # Create an empty collection of attributes
        $AttributeCollection = New-Object System.Collections.ObjectModel.Collection[System.Attribute]

        # Set the Parameter attribute values
        $ParameterAttribute = New-Object System.Management.Automation.ParameterAttribute
        $ParameterAttribute.Position = 0
        #$ParameterAttribute.ParameterSetName = 'ByName'
        $ParameterAttribute.ValueFromPipeline = $true
        $ParameterAttribute.ValueFromPipelineByPropertyName = $true
        #$ParameterAttribute.Mandatory = $true

        # Add the Parameter attributes to the attributes collection
        $AttributeCollection.Add($ParameterAttribute)

        $ParameterAlias = New-Object System.Management.Automation.AliasAttribute -ArgumentList ('InterfaceAlias','ifAlias')
        $AttributeCollection.Add($ParameterAlias)

        # Set the ValidateSet attribute
        $NetAdapterNameSet = Get-NetAdapter | Select-Object -ExpandProperty Name
        $AttributeCollection.Add((New-Object System.Management.Automation.ValidateSetAttribute($NetAdapterNameSet)))

        # Instantiate and add this dynamic/runtime parameter to the RuntimeParameterDictionary
        $RuntimeParameter = New-Object System.Management.Automation.RuntimeDefinedParameter($ParameterName, [string], $AttributeCollection)
        $RuntimeParameter.Value = '*'

        $RuntimeParameterDictionary.Add($ParameterName, $RuntimeParameter)
        # End Dynamic parameter definition

        # When done building dynamic parameters, return
        return $RuntimeParameterDictionary

    } # end DynamicParam

    begin {
        # Start by evaluating parameters
        $NetAdapterParameters = @{}

        # Get-NetAdapter by Name
        if ('Name' -in $PSBoundParameters.Keys) {
            Write-Verbose -Message ('Add Name {0} to $NetAdapterParameters' -f $Name)
            $NetAdapterParameters.Add('Name' , $Name)
        }

        # Get-NetAdapter by Index
        if ('InterfaceIndex' -in $PSBoundParameters.Keys) {
            Write-Verbose -Message ('Add InterfaceIndex {0} to $NetAdapterParameters' -f $InterfaceIndex)
            $NetAdapterParameters.Add('InterfaceIndex' , $InterfaceIndex)
        }

        # Get-NetAdapter -Physical only, or include virtual devices
        if ('IncludeVirtual' -in $PSBoundParameters.Keys) {
            Write-Verbose -Message ('IncludeVirtual: {0}' -f $IncludeVirtual)
        } else {
            Write-Verbose -Message ('Physical: {0}' -f $true)
            $NetAdapterParameters.Add('Physical' , $true)
        }
    }

    process {
        # Get-NetAdapter object(s) by parameter splatting
        try {
            $ActiveAdapter = Get-NetAdapter @NetAdapterParameters | Where-Object -FilterScript {$_.Status -eq $Status} -ErrorAction SilentlyContinue | Select-Object -Property if* # Get-NetAdapterStatistics -Name $Name
        }
        catch {
            throw 'Failed to get an active network adapter to return DNS settings for.'
        }
        Write-Verbose -Message ('Getting DNS Server/Resolver address(es) for active network adapter {0} (InterfaceIndex {1})' -f $ActiveAdapter.ifAlias, $ActiveAdapter.ifIndex)

        $CurrentDNS = Get-DnsClientServerAddress -InterfaceIndex $ActiveAdapter.ifIndex -ErrorAction Stop
        # It seems the DnsClientServerAddress AddressFamily property is programatically an integer, although the cmdlet displays a string
        # IPv4 = 2; IPv6 = 23
        $IPv4DNS = $CurrentDNS | where-object -FilterScript {$_.AddressFamily -eq '2'}
        $IPv6DNS = $CurrentDNS | where-object -FilterScript {$_.AddressFamily -eq '23'}

        Write-Verbose -Message ('IPv4 DNS server address list is {0}' -f $($IPv4DNS.ServerAddresses -join ', '))
        Write-Verbose -Message ('IPv6 DNS server address list is {0}' -f $($IPv6DNS.ServerAddresses -join ', '))

        $ActiveAdapter | Add-Member -Name DNS.IPv4.ServerAddresses -Value $IPv4DNS.ServerAddresses -MemberType NoteProperty
        $ActiveAdapter | Add-Member -Name DNS.IPv6.ServerAddresses -Value $IPv6DNS.ServerAddresses -MemberType NoteProperty

    }

    end {
        #Write-Output -InputObject 'Active network adapter DNS server settings'
        return $ActiveAdapter
    }
}

Write-Verbose -Message 'Importing function Set-MyDNS'
function Set-MyDNS {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact='High')]
    Param (
        [Parameter(Position=0, ParameterSetName='ByIndex', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateScript({$PSItem -in (Get-NetAdapter | Select-Object -ExpandProperty ifIndex)})]
        [Alias('ifIndex')]
        [Int]
        $InterfaceIndex = (Get-NetAdapter | Select-Object -ExpandProperty ifIndex | Sort-Object | Select-Object -First 1),
        [Parameter(Position=0, Mandatory, ParameterSetName='ByName', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateScript({$PSItem -in (Get-NetAdapter | Select-Object -ExpandProperty ifAlias)})]
        [Alias('InterfaceAlias','ifAlias')]
        [String]
        $Name = (Get-NetAdapter | Select-Object -ExpandProperty ifAlias | Sort-Object | Select-Object -First 1),
        [Parameter(Position=1)]
        [ValidateSet('Charter','Custom','Default','DHCP','CloudFlare','Google','OpenDNS','Quad9','UltraDNS')]
        [String]
        $DNSprovider,
        [switch]
        $Force
    )

    begin {

        # Set-DnsClientServerAddress requires elevated privileges; let's see if we've got them

        function Test-LocalAdmin {
            Return ([security.principal.windowsprincipal][security.principal.windowsidentity]::GetCurrent()).isinrole([Security.Principal.WindowsBuiltInRole] 'Administrator')
        }

        if (Test-LocalAdmin) {
            Write-Verbose -Message 'Current user has Administrator permissions; ok to proceed.'
        } else {
            Write-Warning -Message 'Current user does NOT have the Administrator permissions required to proceed.'
            throw 'insufficient privileges. Start Windows PowerShell by using the Run as Administrator option, and then try running the script again.'
        }

        # Charter Spectrum, as tested to be fasted (using GRC DNS Benchmark 5/8/2019)
        $CharterDNS = @{
            Name = 'Charter'
            AddressFamily = 'IPv4'
            # 69.146.17.2, 69.146.17.3
            IPv4 = @('69.146.17.3', '69.146.17.2')
            #IPv6 = @('2606:4700:4700::1001', '2620:fe::9')
        }
        
        # Describe custom objects for describing preferred DNS server configurations
        $CustomDNS = @{
            Name = 'Custom'
            AddressFamily = 'Both'
            # 74.82.42.42, 1.0.0.1, 8.8.4.4
            IPv4 = @('156.154.71.3', '9.9.9.9')
            IPv6 = @('2606:4700:4700::1001', '2620:fe::9')
        }

        # CloudFlare / https://1.1.1.1/
        # IPv4: 1.1.1.1 and 1.0.0.1
        # IPv6: 2606:4700:4700::1111 and 2606:4700:4700::1001
        $CloudFlareDNS = @{
            Name = 'CloudFlare'
            AddressFamily = 'Both'
            IPv4 = @('1.0.0.1', '1.1.1.1')
            IPv6 = @('2606:4700:4700::1111', '2606:4700:4700::1001')
        }

        # OpenDNS
        # 208.67.222.222 and 208.67.220.220
        # https://www.opendns.com/about/innovations/ipv6/
        # 2620:119:35::35, 2620:119:53::53
        $OpenDNS = @{
            Name = 'OpenDNS'
            AddressFamily = 'Both'
            IPv4 = @('208.67.222.222', '208.67.220.220')
            IPv6 = @('2620:119:35::35', '2620:119:53::53')
        }

        # https://www.quad9.net/microsoft/
        # 9.9.9.9 and 149.112.112.112
        # IPv6 = 2620:fe::fe and 2620:fe::9
        $Quad9DNS = @{
            Name = 'Quad9'
            AddressFamily = 'Both'
            IPv4 = @('9.9.9.9', '149.112.112.112')
            IPv6 = @('2620:fe::fe', '2620:fe::9')
        }

        # https://developers.google.com/speed/public-dns/docs/using
        # 8.8.8.8, 8.8.4.4
        # 2001:4860:4860::8888, 2001:4860:4860::8844
        $GoogleDNS = @{
            Name = 'Google'
            AddressFamily = 'Both'
            IPv4 = @('8.8.4.4', '8.8.8.8')
            IPv6 = @('2001:4860:4860::8888', '2001:4860:4860::8844')
        }

        # Neustar UltraRecursive
        # Family Secure
        # IPv4: 156.154.70.3, 156.154.71.3
        # IPv6: 2610:a1:1018::3, 2610:a1:1019::3
        $UltraDNS = @{
            Name = 'Ultra'
            AddressFamily = 'Both'
            IPv4 = @('156.154.71.3', '156.154.70.3')
            IPv6 = @('2610:a1:1018::3', '2610:a1:1019::3')
        }

    <#
        Write-Verbose -Message '$TrustedDNS configurations:'
        $TrustedDNS = @{
            'Custom'     = $CustomDNS
            'CloudFlare' = $CloudFlareDNS
            'OpenDNS'    = $OpenDNS
            'Quad9'      = $Quad9DNS
            'Google'     = $GoogleDNS
        }
    #>
    }

    process {
        # digest DNS provider parameter to determine the target state
        switch ($DNSprovider) {
            {$PSItem -in 'DHCP', 'Default'} {
                $PreferredDNS = @{
                    Name = 'DHCP'
                }
            }
            'Charter' {
                $PreferredDNS = $CharterDNS
            }
            'Custom' {
                $PreferredDNS = $CustomDNS
            }
            'CloudFlare' {
                $PreferredDNS = $CloudFlareDNS
            }
            'Google' {
                $PreferredDNS = $GoogleDNS
            }
            'OpenDNS' {
                $PreferredDNS = $OpenDNS
            }
            'Quad9' {
                $PreferredDNS = $Quad9DNS
            }
            'UltraDNS' {
                $PreferredDNS = $UltraDNS
            }
            Default {
                Write-Warning -Message 'No known DNS provider name specified. Reverting to DHCP.'
                $PreferredDNS = @{
                    Name = 'DHCP'
                }
            }
        }

        # Get current state to compare with target state
        if ('Name' -in $PSBoundParameters.Keys) {
            Write-Verbose -Message ('Add Name {0} to $MyNetAdapterParameters' -f $Name)
            $MyNetAdapterParameters = @{
                Name = $Name
            }
        }

        if ('InterfaceIndex' -in $PSBoundParameters.Keys) {
            Write-Verbose -Message ('Add InterfaceIndex {0} to $MyNetAdapterParameters' -f $InterfaceIndex)
            $MyNetAdapterParameters = @{
                InterfaceIndex = $InterfaceIndex
            }
        }

        Write-Verbose -Message 'Current DNS configuration (via Get-MyDNS)'
        try {
            if (Test-Path -Path Variable:\MyNetAdapterParameters) {
                # Get the DNS server settings for the specified Network Adapter
                $CurrentMyDNS = Get-MyDNS @MyNetAdapterParameters
            } else {
                # Get the DNS server settings for the default network adapter
                $CurrentMyDNS = Get-MyDNS
            }
        }
        catch {
            throw 'Failed to Get an active network adapter to apply DNS settings for.'
        }

        # Enhancement idea -- if current state does not match target state, then set it for the specified adapter

        if ($PreferredDNS.Name -eq 'DHCP') {
            Write-Verbose -Message 'Resetting DNS to default (DHCP)'
            $DnsClientServerAddressParameters = @{
                InterfaceIndex = $CurrentMyDNS.ifIndex
                ResetServerAddresses = $true
            }
        } else {
            Write-Verbose -Message ('Setting Dns Client Server (Resolver) Address(es) to {0}' -f $PreferredDNS.Name)

            switch ($PreferredDNS.AddressFamily) {
                'Both' {
                    Write-Verbose -Message 'AddressFamily: Both'
                    $DNSServerAddresses = $PreferredDNS.IPv4 + $PreferredDNS.IPv6 -join ','
                }
                'IPv4' {
                    Write-Verbose -Message 'AddressFamily: IPv4'
                    $DNSServerAddresses = $PreferredDNS.IPv4 -join ','
                }
                'IPv6' {
                    Write-Verbose -Message 'AddressFamily: IPv6'
                    $DNSServerAddresses = $PreferredDNS.IPv6 -join ','
                }
                Default {
                    Write-Verbose -Message 'AddressFamily: Default'
                    $DNSServerAddresses = $PreferredDNS.IPv4 -join ','
                }
            }

            $DnsClientServerAddressParameters = @{
                InterfaceIndex = $CurrentMyDNS.ifIndex
                ServerAddresses = $DNSServerAddresses
            }
        }

        if ($Force -OR $PSCmdlet.ShouldProcess(('network adapter with ifIndex {0}' -f $CurrentMyDNS.ifIndex))) {
            # Set-DnsClientServerAddress requires elevated privileges / -RunAsAdministrator
            Set-DnsClientServerAddress @DnsClientServerAddressParameters
        }

    }

    end {
        Write-Verbose -Message 'Confirm final DNS configuration (with Get-MyDNS)'
        try {
            if (Test-Path -Path Variable:\MyNetAdapterParameters) {
                # Get the DNS server settings for the specified Network Adapter
                Get-MyDNS @MyNetAdapterParameters
            } else {
                # Get the DNS server settings for the default network adapter
                Get-MyDNS
            }
        }
        catch {
            throw 'Failed to get an active network adapter to enumerate DNS settings for.'
        }
    }
}

<#
    function Test-PowerUser {
        Return ([security.principal.windowsprincipal][security.principal.windowsidentity]::GetCurrent()).isinrole([Security.Principal.WindowsBuiltInRole] 'PowerUser')
    }

    'Test-PowerUser'
    Test-PowerUser

    function Test-SystemOperator {
        Return ([security.principal.windowsprincipal][security.principal.windowsidentity]::GetCurrent()).isinrole([Security.Principal.WindowsBuiltInRole] 'SystemOperator')
    }

    'Test-SystemOperator'
    Test-SystemOperator
#>