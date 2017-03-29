#requires -modules PowerShellGet
# Thanks to @jsnover : https://twitter.com/jsnover/status/739869719532969984
# 6/6/16, 11:21 AM
# Here's a 1-liner to find all the modules that have been updated this week:
# $n=[datetime]::Now;fimo|?{($n-$_.PublishedDate).Days-le7}|ogv

# $n = [datetime]::Now;fimo|Where-Object{($n-$_.PublishedDate).Days -le 1} | Format-List -Property Name,Description
$age = [int]10
$today = [datetime]::Now
Find-Module | Where-Object{($today-$_.PublishedDate).Days -le $age} | Format-List -Property Name,Description

<#
Install-Module -Name ImportExcel -Scope CurrentUser
Install-Module -Name AWSPowerShell -Scope CurrentUser
Install-Module -Name 7Zip4Powershell -Scope CurrentUser
Install-Module -Name Beaver -Scope CurrentUser
Install-Module -Name dbatools -Scope CurrentUser
Install-Module -Name GlobalFunctions -Scope CurrentUser
Install-Module -Name vSphereDSC -Scope CurrentUser
Install-Module -Name PesterHelpers -Scope CurrentUser
#>