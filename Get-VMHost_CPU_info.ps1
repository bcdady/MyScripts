# Get-VMHost | Select Name,Manufacturer,Model,PowerState,ProcessorType,HyperthreadingActive,NumCpu,CpuTotalMhz,CpuUsageMhz | Export-Csv -Path 'H:\My Documents\GBCI vSphere World CPU Report 20161117.csv' -NoTypeInformation -Append
<#
Name                 : gbci02mcesx03.glacierbancorp.local
NumCpu               : 32
CpuTotalMhz          : 73408
CpuUsageMhz          : 18620
PowerState           : PoweredOn
ProcessorType        : Intel(R) Xeon(R) CPU E5-2698 v3 @ 2.30GHz
HyperthreadingActive : True
State                : Connected
Uid                  : /VIServer=glacierbancorp\bdady2@gbci02vc01:443/VMHost=HostSystem-host-71670
Manufacturer         : Cisco Systems Inc
LicenseKey           : 8502M-27057-18L48-003AH-04KPM
Model                : UCSB-B200-M4

#>

# Define Logging tokens
$outFile = Join-Path -Path "$([Environment]::GetFolderPath('MyDocuments'))" -ChildPath "$('GBCI vSphere World Report', "$(Get-Date -UFormat '%Y%m%d')" -join ' ').csv"

# http://www.vmwareadmins.com/list-the-hostname-cluster-name-memory-size-cpu-sckets-and-cpu-cores-of-each-esx-host-using-powercli/

#$vStatsCollection = @()
ForEach ($Cluster in Get-Cluster)
{
    ForEach ($vmhost in ($cluster | Get-VMHost))
    {
        $VMView = $VMhost | Get-View
#        $VMSummary = “” | Select HostName, ClusterName, MemorySizeGB, CPUSockets, CPUCores
#        $VMSummary.ClusterName  = $Cluster.Name
#        $VMSummary.HostName     = $VMhost.Name
#        $VMSummary.MemorySizeGB = $VMview.hardware.memorysize / 1024Mb
#        $VMSummary.CPUSockets   = $VMview.hardware.cpuinfo.numCpuPackages
#        $VMSummary.CPUCores     = $VMview.hardware.cpuinfo.numCpuCores
#    $vStatsCollection      += $VMSummary
        # Update custom object with these properties
        $script:properties = [ordered]@{
            'ClusterName'      = $Cluster.Name
            'HostName'         = $VMhost.Name
            'ClusterHostCount' = ($cluster | Get-VMHost).Count # (Get-Cluster -Name GBCI02SPLESXCLUSTER01 | Get-VM).Count
            'ClusterVMCount'   = ($cluster | Get-VM).Count # (Get-Cluster -Name GBCI02SPLESXCLUSTER01 | Get-VM).Count
            'HostCPUSockets'   = $VMview.hardware.cpuinfo.numCpuPackages
            'HostCPUCores'     = $VMview.hardware.cpuinfo.numCpuCores
            'HostMemGB'        = [math]::Round($VMview.hardware.memorysize/1Gb)
        }
        $script:RetObject = New-Object -TypeName PSObject -Property $properties
    }
    $script:RetObject | Export-Csv -Path $outFile -NoTypeInformation -Append
}
