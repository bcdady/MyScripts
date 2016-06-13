#requires -Version 2 -Modules GroupPolicy

<#
.SYNOPSIS
Enumerate all Active Directory Group Policy Objects that do not appear linked to an OU
.DESCRIPTION
Search for all GPOs with an XML attribute of <LinksTo>, which is empty / null
.PARAMETER 

.NOTES
NAME        :  Get-UnlinkedGPO
VERSION     :  1.0.0.0   
LAST UPDATED:  8/11/2015
AUTHOR      :  Bryan Dady
.LINK
http://powerschill.com/powershell/locating-all-of-the-unlinked-gpos-in-your-domain/
.LINK
GroupPolicy 
.INPUTS
None
.OUTPUTS
None
#>

Import-Module -Name GroupPolicy

Get-GPO -All | 
ForEach-Object -Process { 
    If ( $_ |
        Get-GPOReport -ReportType XML |
    Select-String -NotMatch -Pattern '<LinksTo>' )
    {
        Write-Host -Object $_.DisplayName
    }
}

char
