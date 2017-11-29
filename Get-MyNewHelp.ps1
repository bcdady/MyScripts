
<#
  Author: Bryan Dady
  Version: 0.0.3
  Purpose: Confirm permissions, and update PowerShell help files from the internet

  Version History:
    0.0.2 - Exclude PSLogger module dependency. Exclude dysfunctional $Global:PSState logic, and update some comments
    0.0.3 - Migrate related script block from Profile; name new function Get-MyNewHelp. Rename prior Get-MyNewHelp as Get-MyModuleHelp
#>

[cmdletbinding(SupportsShouldProcess)]
param()

Write-Verbose -Message 'Declaring function Get-MyModuleHelp'
Function Get-MyModuleHelp {
    [cmdletbinding(SupportsShouldProcess)]
    param()
    # Check for prerequisite local admin role/rights, then try to update PowerShell help files for installed modules, from the internet
    Write-Verbose -Message 'Checking for admin permissions to update Help files'
    if (([security.principal.windowsprincipal] [security.principal.windowsidentity]::GetCurrent()).isinrole([Security.Principal.WindowsBuiltInRole] 'Administrator')) {
      # if (-not ($Global:PSState)) {
      #   Write-Warning -Message "Fatal Error loading PowerShell saved state info from custom object: $PSState"
      # }
      # Check $PSHelpUpdatedDate, from previously saved state, should be loaded from json file into variable by Sperry     
      # $PSHelpUpdatedDate = Get-Date -Date ($Global:PSState.HelpUpdatedDate -as [DateTime])
      # Write-Verbose -Message "PS Help (Last) Updated Date: $PSHelpUpdatedDate"
      # $NextUpdateDate = $PSHelpUpdatedDate.AddDays(10)
      # Write-Debug -Message "PS Help Next Update Date: $NextUpdateDate"
      # # Is today on or after $NextUpdateDate ?
      # if ($NextUpdateDate -ge (Get-Date)) {
      #   # We DON'T need to Update Help right now
      #   $updateNow = $false
      #   Write-Debug -Message "We DON'T need to Update Help right now"
      # } else {
        Write-Debug -Message 'Iterate through current modules that have a HelpInfoUri defined, and attempt to update their help'
        # Iterate through current modules that have a HelpInfoUri defined, and attempt to update their help 
        Get-Module -ListAvailable |
        Where-Object -Property HelpInfoUri |
        Sort-Object -Property Name -Unique |
        ForEach-Object -Process {
          "Update-Help -Module $($PSItem.Name)"
          Update-Help -Module $($PSItem.Name)
        }

        # Write-Debug -Message "Update `$PSHelpUpdatedDate to today"
        # $PSHelpUpdatedDate = (Get-Date -DisplayHint Date -Format d)
        # # Update custom object property, and write to settings state file 
        # Write-Debug -Message "`$PSHelpUpdatedDate is $PSHelpUpdatedDate"
        # $Global:PSState.HelpUpdatedDate = $PSHelpUpdatedDate
        # Write-Debug -Message "`$Global:PSState is $Global:PSState"

        # Set-Content -Path $PSProgramsDir\Microsoft.PowerShell_state.json -Value ($Global:PSState | ConvertTo-Json) -Confirm
      # }
    } else {
      Write-Log -Message "Skipping update-help, because we're either not on Windows, or do not have admin permissions" -Verbose # `nConsider using get-help [term] -Online"
    }
}

Write-Verbose -Message 'Declaring function Get-MyNewHelp'
Function Get-MyNewHelp {
    [cmdletbinding(SupportsShouldProcess)]
    param()
    # Preset variable
    $UpdateHelp = $false
    # Define constant: UNC path of previously saved PowerShell Help files
    $HelpSource = '\\hcdata\apps\IT\PowerShell-Help'
    # Check if Write-Log function is available
    if (Get-Command -Name Write-Log -CommandType Function -ErrorAction Ignore) {
        $UpdateHelp = $true
        Write-Debug -Message "`$UpdateHelp: $UpdateHelp"
    } else {
        # This PowerShell session does not know about the Write-Log function, so we try to get a copy from the repository
        Get-Module -ListAvailable -Name PSLogger | Format-List -Property Name,Path,Version
        Write-Warning -Message 'Failed to locate Write-Log function locally. Attempting to load PSLogger module remotely'
        try {
            Import-Module -Name \\hcdata\apps\IT\PowerShell-Modules\PSLogger -ErrorAction Stop
            # double-check if Write-Log function is available
            if (Get-Command -Name Write-Log -CommandType Function -ErrorAction Stop) {
                $UpdateHelp = $true
                Write-Debug -Message "`$UpdateHelp: $UpdateHelp"
            }
        }
        catch {
            'No R: drive mapped. Get a copy of the PSLogger module installed, e.g. from R:\IT\PowerShell-Modules\PSLogger,'
            'then re-try Update-Help -SourcePath $HelpSource -Recurse -Module Microsoft.PowerShell.'
        }
    }
    Write-Verbose -Message "`$UpdateHelp: $UpdateHelp"

    # Check admin rights / role; same approach as Test-LocalAdmin function in Sperry module
    $IsAdmin = (([security.principal.windowsprincipal] [security.principal.windowsidentity]::GetCurrent()).isinrole([Security.Principal.WindowsBuiltInRole] 'Administrator'))
    # Try to update PS help files, if we have local admin rights
    if ($UpdateHelp -and $IsAdmin) {
        if (Test-Path -Path $HelpSource) {
            Write-Log -Message "Preparing to update PowerShell Help from $HelpSource" -Verbose
            Update-Help -SourcePath $HelpSource -Recurse -Module Microsoft.PowerShell.*
            Write-Log -Message "PowerShell Help updated. To update help for all additional, available, modules, run Update-Help -SourcePath `$HelpSource -Recurse" -Verbose
        } else {
            Write-Log -Message "Failed to access PowerShell Help path: $HelpSource" -Verbose
        }
    } else {
      Write-Log -Message "Skipping update-help, because we're either not on Windows, or do not have admin permissions" -Verbose # `nConsider using get-help [term] -Online"
    }
}