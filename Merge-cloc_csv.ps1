
[cmdletbinding()]
Param()

# ! Remove /3p/ after testing, to process the full /GitStats directory structure
$SourcePath = Resolve-Path -Path '~/repo/GitStats/3p'
$TargetFile = Join-Path -Path $SourcePath -ChildPath 'GitLab_stats_summary.csv'

Write-Verbose -Message ('$SourcePath is {0}' -f $SourcePath)
Write-Verbose -Message ('$TargetFile is {0}' -f $TargetFile)

#$CSVfiles = 
('Get-ChildItem -Path {0} -Name *.csv -Recurse' -f $SourcePath)
Get-ChildItem -Path $SourcePath -Name *.csv -Recurse

ForEach-Object -InputObject $CSVfiles -Process {
    Select-Object -InputObject $PSItem -Property Name, FullName
    $PSItem.GetType()
    $ThisFile = Get-ChildItem -Path $PSItem
    $PSItem | Select-Object -Property *Name
    Write-Verbose -Message ('FullName property is {0}' -f $ThisFile.FullName)
    Write-Verbose -Message ('Appending contents of {0} to {1}' -f $ThisFile.FullName, $TargetFile)
    Start-Sleep -Seconds 1
    # Add-Content -Path $TargetFile -Value $(Get-Content -Path $ThisFile.FullName)
}
Write-Verbose -Message 'Done'