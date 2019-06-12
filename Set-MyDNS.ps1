#Requires -Version 3
#-PSEdition Desktop
#========================================
# NAME      : Set-MyDNS.ps1
# LANGUAGE  : Windows PowerShell
# AUTHOR    : Bryan Dady
# VERSION   : 1.0.2
# UPDATED   : 06/11/2019 - Make it work in PowerShell Core (7 preview, incl. Linux support)
# COMMENT   : Set (or reset) the DNS configuration for my local network adapter (e.g. Wi-Fi).
#             This is intended to make alternating from well-known DNS service providers (like CloudFlare 1.1.1.1, OpenDNS, etc.) and DHCP defaults.
#========================================
[CmdletBinding()]
Param()
Set-StrictMode -Version latest


Write-Verbose -Message 'Importing function Get-NetInterface'
function Get-NetInterface {
    [CmdletBinding()]
    param ()

    # Enumerate network interfaces, and determine the active/default interface, based on the network interface attached to the default gateway
    # default via 192.168.0.1 dev wlp2s0 proto dhcp metric 600 

    Write-Verbose -Message 'Getting network connection - Default Gateway'
    $null = (ip route | grep default) -match 'default via (?<gateway>\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}) dev (?<interface>\S+) proto (?<proto>\S+) metric (?<metric>\d+)'
    # PS .\>$Matches

    # Name                           Value
    # ----                           -----
    # metric                         600
    # proto                          dhcp
    # interface                      wlp2s0
    # gateway                        192.168.0.1
    # 0                              default via 192.168.0.1 dev wlp2s0 proto dhcp…
    $Interface = [ordered]@{
        Name     = $Matches.interface
        Gateway  = $Matches.gateway
        Protocol = $Matches.proto
    }

    Write-Verbose -Message ('Default Gateway is {0}. The associated network interface {1}' -f $Interface.Gateway, $Interface.Name)

    # Get address info for this default interface
    Write-Verbose -Message ('Getting additional info for network interface is {0}' -f $Interface.Name)
    $if_info = (ip address show dev $Interface.Name)
    <# Sample output:
        2: wlp2s0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1440 qdisc fq_codel state UP group default qlen 1000
            link/ether c4:8e:8f:f8:e0:cd brd ff:ff:ff:ff:ff:ff
            inet 192.168.0.182/24 brd 192.168.0.255 scope global dynamic noprefixroute wlp2s0
                valid_lft 6277sec preferred_lft 6277sec
            inet6 fe80::40b3:1cd0:f6cf:21ea/64 scope link noprefixroute 
                valid_lft forever preferred_lft forever
    #>

    # get interface status
    $if_info -match "\b(?<InterfaceIndex>\d+): \S+: .+ state (?<state>\S+) group (?<group>\S+)"
    if ($?) {
        Write-Verbose -Message ('$Matches: {0}' -f $Matches)
    } else {
        Write-Warning -Message 'No Matches'
    }
    ''
    $Interface | Add-Member -Name Index -Value $Matches.InterfaceIndex -MemberType NoteProperty
    $Interface | Add-Member -Name State -Value $Matches.state -MemberType NoteProperty
    $Interface | Add-Member -Name Group -Value $Matches.group -MemberType NoteProperty

    # get interface IPv4 address
    $if_info -match 'inet (?<ip4>\S+)\/'
    $Interface | Add-Member -Name IPv4 -Value $Matches.ip4 -MemberType NoteProperty

    # get interface IPv6 address
    $if_info -match 'inet6 (?<ip6>\S+)\/'
    $Interface | Add-Member -Name IPv6 -Value $Matches.ip6 -MemberType NoteProperty

    return $Interface

}

Write-Verbose -Message 'Importing function Select-Resolver'
function Select-Resolver {
    # Select / collect DNS client (resolver) settings from output of systemd-resolve --status
    [CmdletBinding()]
    Param (
        [Parameter(Position=0,  ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('ifIndex')]
        [Int]
        $InterfaceIndex,
        [Parameter(Position=1,  ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('ifName')]
        [Int]
        $InterfaceName,
        [ValidateSet('Up','Down')]
        [String]
        $Status = 'Up'
    )

    # match "DNS Servers: (keep all matching IP addresses)"
    $DNSservers = (systemd-resolve --status) | grep $InterfaceName
    <# Example output:
    Link 2 (wlp2s0)
        Current Scopes: DNS
        LLMNR setting: yes
        MulticastDNS setting: no
        DNSSEC setting: no
        DNSSEC supported: no
        DNS Servers: 192.168.0.1
                     1.0.0.1
                     1.1.1.1
    #>

}

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

        # Set the ValidateSet attribute -- how do we make this work in Linux/macOS, since they?
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
        # It seems the DnsClientServerAddress AddressFamily property is programmatically an integer, although the cmdlet displays a string
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

        function Test-Privilege {
            # Returns $True if elevated (admin / root) privileges are detected
            if ($IsWindows) {
                Return ([security.principal.windowsprincipal][security.principal.windowsidentity]::GetCurrent()).isinrole([Security.Principal.WindowsBuiltInRole] 'Administrator')
            } else {

            }

        }

        if (Test-Privilege) {
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