#requires -Version 3

<#
$corp_Certs = Get-Certificate -StoreName Root -CertStoreLocation .\\LocalMachine -Thumbprint * | Where-Object -FilterScript {
    $PSItem.Subject -ilike "*$Env:USERDOMAIN*"
}
#>

# Use CertMgr.exe to compare with UI

Start-Transcript
$StartingErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'SilentlyContinue'
$BadCerts = Get-ChildItem -Path Cert:\ -Recurse | Where-Object -FilterScript {$PSItem.PSPath -notlike "*Disallowed*" -and $PSItem.NotAfter -lt $((get-date).Date)} | Select-Object -Property PSPath,Subject,Issuer,Version,DnsNameList,NotAfter -ExpandProperty SignatureAlgorithm

$BadCerts | ForEach-Object -Process {
    Write-Verbose -Message ('Removing Certificate: {0}, Subject: {1}, PSPath: {2}, Expiration Date: {3}, Aliases: {4}' -f $PSItem.FriendlyName, $PSItem.Subject, $PSItem.PSPath, $PSItem.NotAfter, $PSItem.DnsNameList ) -verbose
    Remove-Item -Path ('"{0}"' -f $PSItem.PSPath) -Force
}

<#
 - this is a nice idea, but this code is not reliable
    # Cleanup any remaining empty containers
    if ($IsAdmin) {
        Get-ChildItem -Path Cert:\LocalMachine | Where-Object -FilterScript { (Get-ChildItem).count -eq 0 } | Remove-Item -Force
    }

    Get-ChildItem -Path Cert:\CurrentUser | Where-Object -FilterScript { (Get-ChildItem -Path $_.PSPath).count -eq 0 } | Remove-Item -Confirm
#>

$ErrorActionPreference = $StartingErrorActionPreference
Stop-Transcript
