#requires -Version 3

<#
$GBCI_Certs = Get-Certificate -StoreName Root -CertStoreLocation .\\LocalMachine -Thumbprint * | Where-Object -FilterScript {
    $PSItem.Subject -ilike '*glacierbancorp*'
}
#>

Start-Transcript
$ErrorActionPreference = 'SilentlyContinue'
$BadCerts = Get-ChildItem -Path Cert:\ -Recurse | Where-Object -FilterScript {$PSItem.PSPath -notlike "*Disallowed*" -and $PSItem.NotAfter -lt $((get-date).Date)} | Select-Object -Property PSPath,Subject,Issuer,Version,DnsNameList,NotAfter -ExpandProperty SignatureAlgorithm
$ErrorActionPreference = 'Stop'

$BadCerts | ForEach-Object -Process {
    "Removing Certificate with Subject: $($PSItem.Subject), Expiration Date: $($PSItem.NotAfter)"
    Remove-Item -Path $PSItem.PSPath -Force
}
$ErrorActionPreference = 'Continue'
Stop-Transcript
