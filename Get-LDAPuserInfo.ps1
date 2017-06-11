#===============================================================================
# NAME      : Get-LDAPuserInfo.ps1
# LANGUAGE  : Windows PowerShell
# AUTHOR    : Bryan Dady
# DATE      : 03/09/2010
# COMMENT   : Query Active Directory through PowerShell, retrieving user attributes
#===============================================================================
#This code demonstrates how to search and retrieve User Object information from Active Directory
#without any plug-ins.
#
#To run this script within your environment you should only need to copy and paste this script into
#either Windows Powershell ISE or PowerGUI Script Editor,(http://powergui.org) with the following
#changes to the script which I have numbered below.  
#	1.) Change the line, ($strUserName = "samAccountName"), so that you have a real User ID.
#       2.) You may also need to install Microsoft Update "http://support.microsoft.com/kb/968930".
#
#
#You can also search in a specific Active Directory OU By changing the second line of code 
#From: "$objDomain = New-Object System.DirectoryServices.DirectoryEntry"
#To: "$objDomain = New-Object System.DirectoryServices.DirectoryEntry("LDAP://OU=ASDF,DC=asdf,DC=asdf")"


$strUserName = $env:USERNAME
$objDomain = New-Object System.DirectoryServices.DirectoryEntry("LDAP://DC=GBCI,DC=GBCI,DC=GLACIERBANCORP,DC=local")
$objSearcher = New-Object System.DirectoryServices.DirectorySearcher
$strFilter = "(&(objectCategory=User)(samAccountName=" + $strUserName + "))"
$objSearcher.SearchRoot = $objDomain
$objSearcher.PageSize = 1000
$objSearcher.Filter = $strFilter
$objSearcher.SearchScope = "Subtree"
$colResults = $objSearcher.FindAll()

foreach ($objResult in $colResults)
    {$objUser = $objResult.GetDirectoryEntry()
    $objUser.adspath
    "First Name: " + $objUser.FirstName
    "Given Name: " + $objUser.givenName
    "Last Name: " + $objUser.LastName
    "initial: " + $objUser.initials
    "Name: " + $objUser.name
    "CN: " + $objUser.cn
    "FullName: " + $objUser.FullName
    "DisplayName: " + $objUser.DisplayName
    "SamAccountName: " + $objUser.samAccountName
    "UserPrincipalName: " + $objUser.UserPrincipalName
    "badPwdCount: " + $objUser.badPwdCount
    "Comment: " + $objUser.comment
    "Company: " + $objUser.company
    "Country Code: " + $objUser.countryCode
    "Department: " + $objUser.department
    "Description: " + $objUser.description
    "Direct Reports: " + $objUser.directReports
    "Distinguished Name: " + $objUser.distinguishedName
    "facsimileTelephoneNumber: " + $objUser.facsimileTelephoneNumber
    "physicalDeliveryOfficeName: " + $objUser.physicalDeliveryOfficeName
    "TelephoneNumber: " + $objUser.TelephoneNumber
    "mail: " + $objUser.mail
    "wWWHomePage: " + $objUser.wWWHomePage
    "streetAddress: " + $objUser.streetAddress
    "postOfficeBox: " + $objUser.postOfficeBox
    "City: " + $objUser.l
    "State: " + $objUser.st
    "postalCode: " + $objUser.postalCode
    "Country: " + $objUser.c
    "Title: " + $objUser.Title
    "Info: " + $objUser.Info
    #Vintela Authentication Service - uncomment the following lines if you have VAS installed and
    #working within your Active Directory environment.
    #"User ID (uid): " + $objUser.uidNumber
    #"Primary Group ID(gid): " + $objUser.gidNumber
    #"GECOS: " + $objUser.gecos
    #"Login Shell: " + $objUser.loginShell
    #"Unix Home Directory: " + $objUser.unixHomeDirectory
     }