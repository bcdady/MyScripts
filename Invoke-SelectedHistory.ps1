<#PSScriptInfo

.VERSION 1.0

.GUID 018057d7-7bab-4727-817c-e8c89ea01d53

.AUTHOR Jeffrey Snover

.COMPANYNAME 

.COPYRIGHT 

.TAGS 

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES

.DESCRIPTION
   Show the command line history and Invoke the selected items
#>
<#
.Synopsis
   Show the command line history and Invoke the selected items
.DESCRIPTION
   Essentially this does:
    PS> Get-History -count:$count | Out-Gridview -Passthru | Invoke-History

   The benefit is that you can do searching and multiple selections.
.EXAMPLE
   PS> Invoke-SelectedHistory -Whatif
.EXAMPLE
   PS> ISH -count 200 -verbose
.INPUTS
   None
.OUTPUTS
   Output of the selected command
.COMPONENT
.ROLE
.FUNCTIONALITY
#>
[CmdletBinding(SupportsShouldProcess=$true, 
                ConfirmImpact='Medium')]
[Alias("ish")]
Param(
# How many things from history should be shown? 
[Parameter(Mandatory=0,position=0)][Int]$Count= 100   )

foreach($cmd in Get-History -Count:$count |Select Id,CommandLIne,ExecutionStatus,StartExecutionTIme |Out-GridView -PassThru -Title "Select 1 or more commands to invoke" )
{
    if ($pscmdlet.ShouldProcess($cmd.commandline, "Invoke"))
    {
        Invoke-History -Id $cmd.Id 
    }
}
