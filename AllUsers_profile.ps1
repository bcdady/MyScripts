# PowerShell $Profile
# Created by New-Profile function of ProfilePal module

# capture starting path so we can go back after other things below might move around
$startingPath = $pwd

# -Optional- Specify custom font colors
# Uncomment the following if block to tweak the colors of your console; the 'if' statement is to make sure we leave the ISE host alone
# To Uncomment the following block, delete the <# from the next line as well as the matching #> a few lines down
<#
if ($host.Name -eq 'ConsoleHost') {
    $host.ui.rawui.backgroundcolor = 'gray'
    $host.ui.rawui.foregroundcolor = 'darkblue'
    # clear-host refreshes the background of the console host to the new color scheme
    Clear-Host
    # Wait a second for the clear command to refresh
    Start-Sleep -Seconds 1
    # Write to consolehost a copy of the 'Logo' text displayed when one starts a typical powershell.exe session.
    # This is added in because we'd otherwise not see it, after customizing console colors, and then calling clear-host to refresh the console view
    Write-Output @'
Windows PowerShell [Customized by ProfilePal]
Copyright (C) 2013 Microsoft Corporation. All rights reserved.
'@

}
#>

Write-Output "`n`tLoading PowerShell `$Profile: AllUsersAllHosts`n"


Get-Variable -Name Is* -Exclude ISERecent | Format-Table -AutoSize

<# 
Name                           Value                                                                                  
----                           -----                                                                                  
IsCoreCLR                      True                                                                                   
IsLinux                        False                                                                                  
IsOSX                          True                                                                                   
IsWindows                      False  
#>

# Load profile functions module; includes a customized prompt function
# In case you'd like to edit it, open ProfilePal.psm1 in ISE, and review the function prompt {}
# for more info on prompt customization, you can run get-help about_Prompts
write-output ' # loading ProfilePal Module #'
Import-Module -Name ProfilePal

# Do you like easter eggs?: & iex (New-Object Net.WebClient).DownloadString("http://bit.ly/e0Mw9w")
# Here's an example of how convenient aliases can be added to your PS profile
New-Alias -Name rdp -Value Start-RemoteDesktop -ErrorAction Ignore

# In case any intermediary scripts or module loads change our current directory, restore original path, before it's locked into the window title by Set-WindowTitle
Set-Location $startingPath

# Call Set-WindowTitle function from ProfilePal module
Set-WindowTitle

# Display execution policy, for convenience
write-output "`nCurrent PS execution policy is: "
Get-ExecutionPolicy

write-output "`n ** To view additional available modules, run: Get-Module -ListAvailable"
write-output "`n ** To view cmdlets available in a given module, run: Get-Command -Module <ModuleName>"

