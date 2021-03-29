

[CmdletBinding()]
param(
    [Parameter(Mandatory=$True,
        ValueFromPipeline=$True,
        ValueFromPipelineByPropertyName=$True,
        HelpMessage='File to process.'
    )]
    [Alias('File', 'FileName')]
    [ValidateScript({Test-Path -Path $PSItem})]
    [string]$Path,
    [string]$OutputPath = (Split-Path -Path $Path)
)

$pt_grants_regex = "^GRANT (?<privilege>.+) ON (?<table>\S+?) TO '?(?<user>\S+?)'?@'?(?<host>\S+)'?"

Write-Verbose -Message 'Loading function Select-Tokens'

Write-Output -InputObject ('Getting content of file: {0}' -f $Path)
# Get db/server name from $Path file name
$LeafName = Split-Path -Path $Path -Leaf

# parse output file name prefix from input file syntax
$dbName = $LeafName -replace '^prod-'
$dbName = $dbName -replace '-00'
$dbName = $dbName -replace '-grants.txt$'

Write-Verbose -Message ('dbName is: {0}' -f $dbName)

# account for edge case where name is just 'prod-00'
if ($LeafName -like 'prod-00-read-00*') {
    $dbName = 'main-read'
} elseif ($LeafName -like 'prod-00*') {
    $dbName = 'main'
}

Write-Verbose -Message ('server / file name is: {0}' -f $dbName)

Get-Content $Path | ForEach-Object -Process {
    if ($PSItem.Length -ge 3) {
        Write-Verbose -Message ('Parsing line: {0}' -f $PSItem)
        #$result = Select-Tokens -Input $PSItem -ErrorAction SilentlyContinue
        
        $null = ($PSItem -match $pt_grants_regex)
        $Statement = $PSItem
        if ($Matches.user) {
            #$AuditString = ('GRANT {0} ON {1} TO {2}@{3}' -f $Matches.privilege, $Matches.table, $Matches.user, $Matches.host)
            Write-Debug -Message ('[Match]: GRANT {0} ON {1} TO {2}@{3}' -f $Matches.privilege, $Matches.table, $Matches.user, $Matches.host)
            # Test $permission (from $Matches.privilege, in new variable for clarity) for write/edit access
            Write-Verbose -Message ('$Statement: {0}' -f $Statement)
            $permission = $Matches.privilege
            Write-Verbose -Message ('$permission: {0}' -f $permission)
            # if ($Matches.user) {
            $username = $Matches.user

        } else {
            Write-Verbose -Message 'NO MATCH'
            #return ('NO MATCH!' -f $Input)
            $username  = 'err'
            #$Statement = $PSItem
        }
    }

    # does target directory exist? if not, create
    if ($Matches.privilege) {
        $null = ($permission -match '((ALL PRIVILEGES)|(ALTER)|(INSERT)|(UPDATE)|(DELETE))')
        if ($Matches.1) {
            #$Matches
            $elevated = $true # $Matches.1
        }
        if ($elevated) {
            $Statement = ('! {0}' -f $Statement)
        }
        $UserFilePath = Join-Path -Path $OutputPath -ChildPath ('{0}db-{1}-grants.txt' -f $dbName, $username)
        # write $result.0 to users file
        Write-Verbose -Message ('Writing GRANT statement to users file: {0}' -f $UserFilePath)
        # Write-Output -InputObject $Statement # | Out-File -FilePath $UserFilePath -Append -Force
        Add-Content -Path $UserFilePath -Value $Statement -Force 
    }
    Clear-Variable -Name Statement -ErrorAction SilentlyContinue
    Clear-Variable -Name permission -ErrorAction SilentlyContinue
    Clear-Variable -Name username -ErrorAction SilentlyContinue
    Clear-Variable -Name elevated -ErrorAction SilentlyContinue
    Clear-Variable -Name Matches -ErrorAction SilentlyContinue
}

