
[cmdletbinding()]
Param()

$SourcePath = '\\hcdata\GBCI\Shared\Corporate\IT\AD-HR\Processed\*_ActiveEmployeestoAD.csv'
$TargetFile = Join-Path -Path '\\hcdata\homes$\gbci\BDady\My Documents\IT' -ChildPath "UltiPro_$(Get-Date -UFormat '%Y%m%d').csv"

$Active = @()
Get-ChildItem -Path $SourcePath | Sort-Object -Property LastWriteTime | ForEach-Object -Process {
    Write-Verbose -Message "Importing $PSItem"
    Start-Sleep -Seconds 1
    if ($sourceData = Import-Csv -Path $PSItem) {
        Write-Verbose -Message "Adding $($sourceData.Count) rows to `$Active"
        $Active += $sourceData #| Sort-Object -Unique EepEEID 
    } else {
        Write-Warning "Fatal error getting CSV contents of $PSItem"
    }
}
Write-Verbose -Message "Pre-sort `$Active has $($Active.Count) rows"
$Active = $Active | Sort-Object -Unique EepEEID

Write-Verbose -Message "Final `$Active has $($Active.Count) rows"

"Writing to $TargetFile"
$Active | Export-Csv -Path $TargetFile -NoTypeInformation
#Write-Verbose -Message 'Done'

$SourcePath = '\\hcdata\GBCI\Shared\Corporate\IT\AD-HR\Processed\ContactsUpdate-*.csv'
$TargetFile = Join-Path -Path '\\hcdata\homes$\gbci\BDady\My Documents\IT' -ChildPath "CUT_collated-$(Get-Date -UFormat '%Y%m%d').csv"

$Processed = @()
Get-ChildItem -Path $SourcePath | Sort-Object -Property LastWriteTime | ForEach-Object -Process {
    Write-Verbose -Message "Importing $PSItem"
    Start-Sleep -Seconds 1
    if ($sourceData = Import-Csv -Path $PSItem) {
        Write-Verbose -Message "Adding $($sourceData.Count) rows to `$Active"
        $Processed += $sourceData #| Sort-Object -Unique EmployeeID 
    } else {
        throw "Fatal error getting CSV contents of $PSItem"
    }
}
Write-Verbose -Message "Pre-sort `$Processed has $($Processed.Count) rows"
$Processed = $Processed | Sort-Object -Unique EmployeeID

Write-Verbose -Message "Final `$Processed has $($Processed.Count) rows"

"Writing to $TargetFile"
$Processed | Export-Csv -Path $TargetFile -NoTypeInformation
Write-Verbose -Message 'Done'