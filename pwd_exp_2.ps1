Change these variables
$SearchBase = "OU=yourusers,CN=YourDomain,CN=local"
$Age = 2
$SMTPProperties = @{
    From = "script@yourdomain.com"
    To = "helpdesk@yourdomain.com"
    Subject = "Password Expiration Reset"
    SMTPServer = "yourSMTPrelayServer"
}

#Do not change below here
cls
$SearchSplat = @{
    Filter = "*"
}
If ($SearchBase)
{   $SearchSplat.Add("SearchBase",$SearchBase)
    $SearchSplat.Add("SearchScope","Subtree")
}

#Load RSAT
Try { Import-Module ActiveDirectory -ErrorAction Stop }
Catch { Write-Host "Unable to load Active Directory module, is RSAT installed?"; Exit }

#Find out the global domain Password Age
$DomainMode = (Get-ADDomain).DomainMode.Value__
$maxPasswordAgeTimeSpan = (Get-ADDefaultDomainPasswordPolicy).MaxPasswordAge

#Loop through all users, ignore users who are disabled, have their password set to never expire or have never set a password.
$Results = @()
ForEach ($User in (Get-ADUser @SearchSplat -Properties PasswordExpired,PasswordLastSet,PasswordNeverExpires,LastLogonDate))
{   If ($User.PasswordNeverExpires -or $User.PasswordLastSet -eq $null -or $User.Enabled -eq $false)
        {       Continue
        }
    If ($DomainMode -ge 3) 
        {       ## Greater than Windows2008 domain functional level retrieve the granular level password policy
               $accountFGPP = $null
               $accountFGPP = Get-ADUserResultantPasswordPolicy $User
        If ($accountFGPP -ne $null) 
               {       $ResultPasswordAgeTimeSpan = $accountFGPP.MaxPasswordAge
        } 
               Else 
               {       $ResultPasswordAgeTimeSpan = $maxPasswordAgeTimeSpan
        }
        }
        Else
        {       #Otherwise take default domain password age
        $ResultPasswordAgeTimeSpan = $maxPasswordAgeTimeSpan
        }
        $Expiration = $User.PasswordLastSet + $ResultPasswordAgeTimeSpan
        If ((New-TimeSpan -Start (Get-Date) -End $Expiration).Days -le $Age)
        {       $Results += New-Object PSObject -Property @{
                       'Last Name' = $User.Surname
                       'First Name' = $User.GivenName
                       UserName = $User.SamAccountName
                       'Password Expiration Date' = $Expiration
                       'Last Logon Date' = $User.LastLogonDate
               }
        Set-ADUser $User -ChangePasswordAtLogon $true -WhatIf
        }
}

$Header = @"
<style>
TABLE {border-width: 1px;border-style: solid;border-color: black;border-collapse: collapse;}
TH {border-width: 1px;padding: 3px;border-style: solid;border-color: black;background-color: #6495ED;}
TD {border-width: 1px;padding: 3px;border-style: solid;border-color: black;}
</style>
"@

#If we have something email the report
If ($Results)
{   $Body = $Results | Select 'Last Name','First Name',UserName,'Password Expiration Date','Last Logon Date' | ConvertTo-Html -Head $Header -PreContent "<h2>Password Reset Script</h2><p>The following users had their account set to require a password change when they next login.</p><p>" | Out-String
    Send-MailMessage @SMTPProperties -Body $Body -BodyAsHtml
}
