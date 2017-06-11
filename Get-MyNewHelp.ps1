
<#

Author:
Version:
Version History:

Purpose:

#>

[cmdletbinding(SupportsShouldProcess)]
param()

function Get-MyNewHelp
{
  # try to update PS help files, if we have local admin role/rights
  Write-Log -Message 'Checking if PS Help files are due to be updated' -Verbose
  if (([security.principal.windowsprincipal] [security.principal.windowsidentity]::GetCurrent()).isinrole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
  {
    if (-not ($Global:PSState))
    {
      Write-Warning -Message "Fatal Error loading PowerShell saved state info from custom object: $PSState"
    }
    # Check $PSHelpUpdatedDate, from previously saved state, should be loaded from json file into variable by Sperry     
    $PSHelpUpdatedDate = Get-Date -Date ($Global:PSState.HelpUpdatedDate -as [DateTime])
    Write-Verbose -Message "PS Help (Last) Updated Date: $PSHelpUpdatedDate"
    $NextUpdateDate = $PSHelpUpdatedDate.AddDays(10)
    Write-Debug -Message "PS Help Next Update Date: $NextUpdateDate"
    # Is today on or after $NextUpdateDate ?
    if ($NextUpdateDate -ge (Get-Date)) 
    {
      # We DON'T need to Update Help right now
      $updateNow = $false
      Write-Debug -Message "We DON'T need to Update Help right now"
    }
    else
    {
      Write-Debug -Message 'Iterate through current modules that have a HelpInfoUri defined, and attempt to update their help'
      # Iterate through current modules that have a HelpInfoUri defined, and attempt to update their help 
      Get-Module -ListAvailable |
      Where-Object -Property HelpInfoUri |
      Sort-Object -Property Name -Unique |
      ForEach-Object -Process {
        "Update-Help -Module $($PSItem.Name)"
        Update-Help -Module $($PSItem.Name)
      }

      Write-Debug -Message "Update `$PSHelpUpdatedDate to today"
      $PSHelpUpdatedDate = (Get-Date -DisplayHint Date -Format d)
      # Update custom object property, and write to settings state file 
      Write-Debug -Message "`$PSHelpUpdatedDate is $PSHelpUpdatedDate"
      $Global:PSState.HelpUpdatedDate = $PSHelpUpdatedDate
      Write-Debug -Message "`$Global:PSState is $Global:PSState"

      Set-Content -Path $PSProgramsDir\Microsoft.PowerShell_state.json -Value ($Global:PSState | ConvertTo-Json) -Confirm
    }
  }
  else
  {
    Write-Log -Message "Skipping update-help, because we're either not on Windows, or do not have admin permissions" -Verbose # `nConsider using get-help [term] -Online"
  }
}
