
<#
Partially based on
Author: Brian Wilhite
Version: Updated 10/11/2012
Version History: Based partially on https://gallery.technet.microsoft.com/scriptcenter/Get-LastLogon-Determining-283f98ae

Purpose: This function will list the last several users logged in, via WMI, remotely via Invoke-Command.

#>

# $ComputersList can be '.', a single string, or a comma separated/delimited list of IP address(s) or hostname(s) (a FQDN recommended)
$ComputersList = '.'
Invoke-Command -ComputerName $ComputersList -ScriptBlock {Get-CimInstance –ClassName Win32_UserProfile -Filter "Special = 'False' AND LastUseTime IS NOT NULL" -ComputerName $Computer | Sort-Object -Property LastUseTime -Descending -Unique | Select-Object -First 10 -Property LocalPath,LastUseTime,SID}  -Credential (Get-Credential -Message 'Enter alternate/elevated credentials') -AsJob; #-InDisconnectedSession

foreach ($Computer in $ComputersList)
{
    Receive-Job -ComputerName
    Receive-PSSession -ComputerName
}
# Commands that use the InDisconnectedSession parameter return a PSSession object that represents the disconnected session. They do not return the command output. To connect to the disconnected session, use the Connect-PSSession or Receive-PSSession cmdlets. To get the results of commands that ran in the session, use the Receive-PSSession cmdlet.To run commands that generate output in a disconnected session, set the value of the OutputBufferingMode session option to Drop. If you intend to connect to the disconnected session, set the idle timeout in the session so that it provides sufficient time for you to connect before deleting the session.
# You can set the output buffering mode and idle timeout in the SessionOption parameter or in the $PSSessionOption preference variable. For more information about session options, see New-PSSessionOption and about_Preference_Variables.

# # # Test !!! # # # :: Does a new pssession, WinRM, WSMan connection count as an update to LastUseTime?

# [ ] Add to UpGuard? or Splunk?

# https://gallery.technet.microsoft.com/scriptcenter/Scripting-Guys-WMI-Helper-5a03aaeb
Filter Hide-NullWmiValue
{
   $_.properties |
   foreach-object -BEGIN {write-host -ForegroundColor BLUE $_.path} -Process {
     If($_.value -AND $_.name -notmatch '__')
      {
        @{ $($_.name) = $($_.value) }
      } #end if
    } #end foreach property
} #end filter HasWmiValue
