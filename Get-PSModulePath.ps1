# http://wahlnetwork.com/2015/08/10/psmodulepath/

Write-Output -InputObject "User Environment Variable PSModulePath:"
[Environment]::GetEnvironmentVariable('PSModulePath','User') -split ';'

Write-Output -InputObject ''
Write-Output -InputObject "Machine Environment Variable PSModulePath:"
[Environment]::GetEnvironmentVariable('PSModulePath','Machine') -split ';'

Write-Output -InputObject ''
Write-Output -InputObject "Process Environment Variable PSModulePath:"
[Environment]::GetEnvironmentVariable('PSModulePath','Process') -split ';'

<#
# Reset / overwrite to original PSModulePath values
$PSModulePath = "${env:ProgramFiles(x86)}\WindowsPowerShell\Modules;$env:SystemRoot\system32\WindowsPowerShell\v1.0\Modules;$env:ProgramFiles\WindowsPowerShell\Modules;$env:USERPROFILE\Documents\WindowsPowerShell\Modules"

# OR 
#Save the current value in the $p variable.
$p = [Environment]::GetEnvironmentVariable('PSModulePath','User')
#Add the new path to the $p variable. Begin with a semi-colon separator.
$p += ";$Home\Documents\WindowsPowerShell\Modules"
#Add the paths in $p to the PSModulePath value.
[Environment]::SetEnvironmentVariable('PSModulePath',$p,'User')

# Requres admin rights to set/reset Machine level
[Environment]::SetEnvironmentVariable('PSModulePath',"${env:ProgramFiles(x86)}\WindowsPowerShell\Modules;$env:SystemRoot\system32\WindowsPowerShell\v1.0\Modules;$env:ProgramFiles\WindowsPowerShell\Modules",'Machine')

#>