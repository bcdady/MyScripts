<#
.SYNOPSIS
    Retrives DNS Servers from a computer.
.DESCRIPTION
    Retrives primary, secondary, tertiery DNS Servers from on online system using Windows Management Instrimentation.
.INPUTS
    System.String.
.OUPUTS
    System.Management.Automation.PSCustomObject.
.PARAMETER ComputerName
    The computer to retrieve information from.
.PARAMETER Credential
    PSCredential object with rights to the remotly access WMI.
.EXAMPLE
    Get-DnsConfiguration

    PSComputerName      : MyPC
    NetworkAdapter      : Hyper-V Virtual Ethernet Adapter [192.168.1.1]
    PrimaryDNSServer    : 8.8.8.8
    SecondaryDNSSserver : 8.8.4.4
    TertieryDNSServer   : 
.EXAMPLE
    Get-DNSConfiguration -ComputerName 'remotepc.my.org' -Credential (Get-Credential)

    PSComputerName      : remotepc
    NetworkAdapter      : Hyper-V Virtual Ethernet Adapter [192.168.1.1]
    PrimaryDNSServer    : 8.8.8.8
    SecondaryDNSSserver : 8.8.4.4
    TertieryDNSServer   :
.LINK
    http://dotps1.github.io
#>
[OutputType([PSCustomObject])]

Param (
    [Parameter(
        ValueFromPipeline = $true,
        ValueFromPipelineByPropertyName = $true
    )]
    [Alias(
        'ComputerName',
        'PSComputerName'
    )]
    [String[]]
    $Name = $env:COMPUTERNAME,

    [Parameter()]
    [ValidateNotNull()]
    [PSCredential]
    $Credential
)

Process {
    for ($i = 0; $i -lt $Name.Length; $i++) {
        try {
            $gwmiParams = @{
                ComputerName = $Name[$i]
                Class = 'Win32_NetworkAdapterConfiguration'
                Namespace = 'root\cimV2'
                Filter = "IPEnabled='TRUE'"
                ErrorAction = 'Stop'
            }

            if ($Name[$i] -ne $env:COMPUTERNAME -and $Credential -ne $null) {
                $gwmiParams.Add('Credential', $Credential)
            }

            $networkAdapters = Get-WmiObject @gwmiParams
        } catch {
            Write-Error -Message $_.ToString()
            continue
        }

        foreach ($networkAdapater in $networkAdapters) {
            $dnsServers = $networkAdapater.DNSServerSearchOrder

            [PSCustomObject]([Ordered]@{
                PSComputerName = $Name[$i]
                NetworkAdapter = "$($networkAdapater.Description) [$($networkAdapater.IPAddress[0])]"
                PrimaryDNSServer = $dnsServers[0]
                SecondaryDNSSserver = $dnsServers[1]
                TertieryDNSServer = $dnsServers[2]
            })
        }
    }
}

<#PSScriptInfo
.DESCRIPTION
    Retrives primary, secondary, tertiery DNS Servers from on online system using Windows Management Instrimentation.
.VERSION
    1.0
.GUID
    85a1387f-b20b-443c-bea0-ba4181ed7444
.AUTHOR
    Thomas Malkewitz @dotps1
.TAGS
    Dns
.RELEASENOTES 
    Intial Release.
#>