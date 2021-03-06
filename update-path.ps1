<#
    Author: Bryan Dady (@bcdady)
    Version: 0.1.0
    Version History: 2016-10-10
    Purpose:
        Funciton to add/merge new path into $Env:path
        Remove any/all duplicate separators (e.g. ;;)
        Sort and remove any/all duplicate entries
        Replace any/all static path entries to well known directory paths with their variable 
#>

# start-transcript
# backup current path, just in case
write-output -InputObject 'Starting PATH cleanup'
$Env:Path_backup = $Env:PATH
$Global:Path_backup = $Env:PATH
write-output -InputObject 'PATH cloned to $Path_backup'

if ($PSEdition -eq 'Core')
{
    # Use colon character for non-Windows / PS-Core
    $separator = ':'
}
else
{
    # Use semicolon for Windows
    $separator = ';'
}
# remove any/all duplicate separator character
write-output -InputObject 'Removing any redundant seperator'
$Env:PATH = ($Env:PATH).Replace("$separator$separator","$separator")

# sort and remove any/all duplicate entries
write-output -InputObject 'Sorting PATH to unique entries'
$Env:PATH = @($Env:PATH -split $separator | Sort-Object -Unique -Descending) -join $separator


write-output -InputObject 'PATH entries:'
$Env:PATH -split $separator | Sort-Object -Unique -Descending
write-output -InputObject 'PATH cleanup complete'

# $Env:Path = ($Env:Path -split ';') -replace(';*%SystemRoot%[^;]+','') -join ';'

<# replace any/all static path entries to well known directory paths with their variable 
$oldPath = @{}
$newPath = @{}
# gci env: | foreach { "$($PSItem.Value) : `$Env:$($PSItem.Name)" }
gci env: | foreach {
    # for env: variables that look like a path, add to a hashtable of filesystem path variables
    if ((Test-Path -Path $($PSItem.Value) -PathType Container) -and ($PSItem.Name))
    {
        Write-Debug -Message "$($PSItem.Value) could be `$Env:$($PSItem.Name)"
        $oldPath.Add($PSItem.Value, '$Env:'+$($PSItem.Name))
    }
#    else
#    {
#        write-warning -Message "There was an issue with `$Env:$($PSItem.Name) :: $($PSItem.Value)"
#    }
}

start-sleep -s 1

"varPaths"
# $oldPath
foreach ($env_alt in $oldPath.Keys) {
    $env_Path | foreach {
        # before we can use the $oldPath key in a -replace, we have to escape any \ with \\
        $findString = $env_alt -replace('\\','\\\\')
        if ($PSItem -match $findString)
        {
            $replaceString = $oldPath.$env_alt
            Write-Output -InputObject "$PSItem -replace($env_alt,$replacestring)"
            Write-Output -InputObject "`$newPath += $($PSItem -replace($findstring,$replacestring))"
            $newPath += ($PSItem -replace($findstring,$replacestring))
        }
        else
        {
                Write-Output -InputObject "Fault: Did not -match $findString in $PSItem"
        }
    }
}
#>

# $newPath -join $separator
# $Env:PATH = $newPath -join $separator

# END
# stop-transcript
