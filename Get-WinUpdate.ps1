
[int]$inventory = 10 # number of recent updates to enumerate
# get-date -Date (get-date).AddDays('-30') -Format g
[DateTime]$Since = (get-date).AddDays('-30')
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.Update.Session') | Out-Null
$Session = New-Object -ComObject Microsoft.Update.Session

Write-Output -InputObject "`nEnumerating Windows Updates installed since $(Get-Date -Date $Since -UFormat '%m/%d/%Y')"

try {
    $UpdateSearcher   = $Session.CreateUpdateSearcher()
    $NumUpdates       = $UpdateSearcher.GetTotalHistoryCount()
    $InstalledUpdates = $UpdateSearcher.QueryHistory(1, $NumUpdates)
    
    if ($?) {
        # -First $inventory
        return $InstalledUpdates | Sort-Object -Property Date -Descending | Select-Object -Property Date,Title | Where-Object -FilterScript {$PSItem.Date -ge $Since}
        # $LastInstalledUpdate = $InstalledUpdates | Sort-Object -Property Date -Descending | Select-Object -First $inventory Title, Date
        # $LastInstalledUpdate.Title, $LastInstalledUpdate.Date
    }
    else {
        "Error. Win update search query failed: $($Error[0] -replace '[\r\n]+')"
    }
} # end of inner try block

catch {
    $LastUpdateErrors.$Computer = "Error (terminating): $($Error[0] -replace '[\r\n]+')"
    continue
}
