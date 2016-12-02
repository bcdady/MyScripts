
<#PSScriptInfo

.VERSION 1.2

.GUID efd8653f-3a23-4d78-a7d1-b766da9015bf

.AUTHOR Chris Carter

.COMPANYNAME 

.COPYRIGHT ©2016 Chris Carter

.TAGS Active Directory, Last Logon Time

.LICENSEURI http://creativecommons.org/licenses/by-sa/4.0/

.PROJECTURI https://gallery.technet.microsoft.com/Export-Last-Logon-Times-4fcb07cb

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES The script was changed to remove the error message boxes, because I couldn't remember why it would use them in the first place.  Also, the script has been changed so that it now retrieves the LastLogon property from all domain controllers to find the most recent login time. 


#>

<#
.SYNOPSIS
This script will export the account name and the last logon time of the users in the specified OU to a .csv file format at the specified destination.

.DESCRIPTION
This script takes the OU common name specified in the OU parameter and retrieves its users' account names and last logon times.  Then it exports a .csv file to the destination given in the Destination parameter.  This script will search the entire domain for the OU name specified.  If you have OUs with the same names this script will most likely fail.  If the destination path contains spaces it must be wrapped in quotation marks, and the file name specified must end in .csv. 
 
Due to the common problem of the LastLogon not replicating between domain controllers, this script will search for domain controllers and compare the LastLogon from each one to find the most recent time a user logged in.
.PARAMETER OrganizationalUnit
Specifies the common name of the OU from which to retrieve users.  Do not enter the distinguished name of the OU, i.e. OU=Users,DC=example,DC=com.  The script will resolve the distinguished name.

.PARAMETER Destination
Specifies the location and file name of the exported csv file.  If you do not specify a full path, the current location will be used.  The file name must have a .csv extension specified.

.INPUTS
None.  You cannot pipe objects to Export-LastLogonTimes.ps1.

.OUTPUTS
None.  Export-LastLogonTimes.ps1 does not generate any output.

.EXAMPLE
The following command will get the account name and last logon times for the OU named Users and export the information to a .csv file named LastLogon.csv in the Administrator's Documents folder.

PS C:\> Export-LastLogonTimes -OU Users -Destination "C:\Users\administrator\Documents\LastLogon.csv"

.NOTES
This script uses the ActiveDirectory PowerShell Module. This module is automatically installed on domain controllers and workstations or member servers that have installed the Remote Server Administration Tools (RSAT).  If you are not on a machine that meets this criteria, the script will fail to work.

.LINK
Get-ADUser
.LINK
Get-ADObject
.LINK
Get-ADDomainController
.LINK
Export-Csv
#>

#Binding for Common Parameters
[CmdletBinding(HelpURI='https://gallery.technet.microsoft.com/Export-Last-Logon-Times-4fcb07cb')]

Param(
    [Parameter(Mandatory=$true, Position=0)]
    [Alias("OU")]
        [String]$OrganizationalUnit,

    [Parameter(Mandatory=$true, Position=1)]
    [ValidatePattern("\.csv$")]
        [String]$Destination
)

#Function to test for module installation and successful load.  Thank you to Hey, Scripting Guy! blog for this one.
Function Test-Module {
    Param (
        [Parameter(Mandatory=$true, Position=0)][String]$Name
    )

    #Test for module imported
    if (!(Get-Module -Name $Name)) {
        #Test for module availability
        if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $Name}) {
            #If not loaded but available, import module 
            Import-Module $Name
            $True
        }
        #Module not installed
        else {$False}
    }
    #Module already imported
    else {$True}
}

#Test for ActiveDirectory Module
if (!(Test-Module -Name "ActiveDirectory")) {
    #If not installed, alert
    Write-Error "There was a problem loading the Active Directory module.  Either you are not on a domain controller or your workstation does not have Remote Server Administration Tools (RSAT) installed."
}
else {
    #Get Domain Controllers - this can take a while
    $DCs = Get-ADDomainController -Filter *

    #Search for input OU and store distinguished name property
    $OUDN = (Get-ADObject -Filter "OU -eq '$OrganizationalUnit'").DistinguishedName

    #test for valid result of OU
    if ($OUDN) {
        
        #If distinguished name exists, get users' account name and last logon times
        $users = Get-ADUser -Filter * -SearchBase $OUDN

        $result = @()

        #Iterate through each user and get its LastLogonDate property from each domain controller
        foreach ($user in $users) {
            $DCLogonTimes = @()
            foreach ($dc in $DCs) {
                try {
                    $DCLogonTimes += (Get-ADUser -Identity $user.SamAccountName -Server $dc.Name -Properties LastLogonDate).LastLogonDate
                }
                catch [Microsoft.ActiveDirectory.Management.ADServerDownException] {
                    Write-Error "PowerShell cannot connect to the server $($dc.Name). The server may be down, or it does not have the Active Directory Web Services running."
                }
            }
            #Sort the dates to get the highest date on top
            $DCLogonTimes = $DCLogonTimes | Sort-Object -Descending
            $result += New-Object PSObject -Property @{SamAccountName = $user.SamAccountName; LastLogonDate = $DCLogonTimes[0]}
        }

        #Sort and export the desired information to a .csv file
        $result = $result | Sort-Object -Property SamAccountName
        $result | Export-Csv -Path $Destination -NoTypeInformation
    }
    #No OU was found with the name supplied
    else {
        #Generate alert for no OU found
        Write-Error "The OU you specified is not a valid OU name in your domain."
    }
}