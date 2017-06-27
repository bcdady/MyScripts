
<#

    Author: Bryan Dady
    Version: 0.1.0
    Version History:

    Purpose: Delete old user profiles from servers
    # Exclude deleting 'Administrator', 'hostmonitor', ... ?

#>

if ( -not (get-variable -Name LastLogon | out-null) )
{
  '$LastLogon = Get-WmiObject -Class win32_userprofile'
  $LastLogon = Get-WmiObject -Class win32_userprofile -Filter Special='False' -ComputerName GBCI02CRA01 -Credential $my2acct | Select-Object -Property @{LABEL='ComputerName';EXPRESSION={$_.__SERVER}}, @{LABEL='UserName';EXPRESSION={$_.LocalPath.Replace('C:\Users\','')}}, @{LABEL='LastLogon';EXPRESSION={$_.ConvertToDateTime($_.lastusetime)}} | Sort-Object -Descending -Property ComputerName, LastLogon, UserName
}

if ( -not (get-variable -Name CutOffDate | out-null) )
{
  '$CutOffDate = (get-date).AddMonths(6)'
  $CutOffDate = (get-date).AddMonths(6)
} 

write-output " Preparing to clean (remove) user profiles older than $($CutOffDate.Date.ToShortDateString())"

foreach ($userprofile in $LastLogon)
{
  'CutOffDate type:'
  ($CutOffDate.Date).GetType()
  
  'LastLogon type:'
  ($userprofile.LastLogon).GetType()
  ($userprofile.LastLogon) -as [date]
  
  if (($CutOffDate.Date.ToShortDateString()) -ge ($userprofile.LastLogon))
  {
    write-output "old profile: $($userprofile.UserName) : $($userprofile.LastLogon)"
  }
  exit
}
