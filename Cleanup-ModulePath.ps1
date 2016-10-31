<#
    Author: Bryan Dady (@bcdady)
    Version: 0.1.0
    Version History: 2016-10-23
    Purpose:
        Funciton to add/merge new path into $Env:PSMODULEPATH
        Remove any/all duplicate separators (e.g. ;;)
        Sort and remove any/all duplicate entries
        Replace any/all static path entries to well known directory paths with their variable 
#>

# backup current path, just in case
$Env:PSMODULEPATH_BACKUP = $Env:PSMODULEPATH
$PSMODULEPATH     = $Env:PSMODULEPATH

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
# Remove any/all duplicate separator character
$PSMODULEPATH = ($PSMODULEPATH).Replace("$separator$separator",$separator)
# sort and remove any/all duplicate entries
$PSMODULEPATH = ($PSMODULEPATH -split $separator | sort -Unique) # -join $separator

# cleanup all but newest version subdir from modules root directories 
 $PSMODULEPATH | Foreach {
    if ($PSItem -notmatch 'system32')
    {
        Get-ChildItem -Path $PSItem -Directory -Exclude .hg,.git* | ForEach {
            #$props = @{
                #Folder = $PSItem.Name
                #"Module folder: $($PSItem.Name)"
                $SubDirCount = (Get-ChildItem -Path $PSItem -Directory | where {$PSItem.Name -match '\d\.+'} | Measure-Object).Count
                #"$PSItem - $SubDirCount"
                Write-Output -InputObject "Retaining module $($PSItem.Name)  $(Get-ChildItem -Path $PSItem -Directory | where {$PSItem.Name -match '\d\.+'} | sort -Descending -Property Name | Select -first 1)" -Verbose 
                if ($SubDirCount -gt 1)
                {
                    #$CleanupCount = ($SubDirCount - 1)
                    (Get-ChildItem -Path $PSItem -Directory) | where {$PSItem.Name -match '\d\.+'} | sort -Descending -Property Name | Select -last ($SubDirCount - 1) | foreach { 
                            Write-Output -InputObject " # # # Removing: $($PSItem.Name) # # #" -Verbose
                            Remove-Item -Path $PSItem.FullName -Recurse -Force
                        }
                }
            #}
            #New-Object PSObject -Property $props
        }
    } #| Select-Object Folder,Count
}
