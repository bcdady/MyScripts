#!/usr/local/bin/pwsh
#Requires -Version 3
#========================================
# NAME      : Microsoft.PowerShell_functions.ps1
# LANGUAGE  : Windows PowerShell
# AUTHOR    : Bryan Dady
# UPDATED   : 02/19/2018
# COMMENT   : Shared functions for use in PowerShell
#========================================
[CmdletBinding(SupportsShouldProcess)]
param ()
Set-StrictMode -Version latest

Write-Verbose -Message 'Declaring function Find-UpdatedDSCResource'
function Find-UpdatedDSCResource {
  $MyDSCModules = Get-InstalledModule | Where-Object -FilterScript {($PSItem.Tags -like 'DSC') -and ($PSItem.CompanyName -eq 'PowerShellTeam') -or ($PSItem.Author -like 'Microsoft') } | Select-Object -Property Name, Version

  Write-Output -InputObject 'Checking PowerShellGallery for new or updated DSC Resources (from Microsoft / PowerShellTeam)'
  Write-Verbose -Message 'Find-Package -ProviderName PowerShellGet -Tag DscResource' # | Format-List -Property Name,Status,Summary'
  #Find-Package -ProviderName PowerShellGet -Tag DscResource | Format-List -Property Name,Status,Summary | Out-Host -Paging
  $DSCResources = Find-Module -Tag DscResource -Repository PSGallery | Where-Object -FilterScript {($PSItem.CompanyName -eq 'PowerShellTeam') -or ($PSItem.Author -like 'Microsoft')}
  foreach ($pkg in $DSCResources) {
    Write-Debug -Message "$($pkg.Name) -in $($MyDSCModules.Name)"
    Write-Debug -Message $($pkg.Name -in $MyDSCModules.Name)
    if ($pkg.Name -in $MyDSCModules.Name) {
      # Retrieve matching local DSC resource module info
      $thisMod = $MyDSCModules | Where-Object -FilterScript { $PSItem.Name -eq $($pkg.Name) }
      Write-Debug -Message $thisMod
      Write-Debug -Message ($pkg.Version -gt $thisMod.Version)
      if ($pkg.Version -gt $thisMod.Version) {
        #Write-Verbose -Message 
        Write-Output -InputObject "Update to $($pkg.Name) is available"
        Write-Output -InputObject "Local: $($thisMod.Version) ; Repository: $($pkg.Version)"
        Update-Module -Name $($pkg.Name) -Confirm
      }
    } else {
      Write-Output -InputObject 'Reviewing new DSC Resource module packages available from PowerShellGallery'
      $pkg | Format-List -Property Name, Description, Dependencies, PublishedDate
      if ([string](Read-Host -Prompt 'Would you like to install this resource module? [Y/N]') -eq 'y') {
        Write-Verbose -Message "Installing and importing $($pkg.Name) from PowerShellGallery" -Verbose
        $pkg | Install-Module -Scope CurrentUser -Confirm
        Import-Module -Name $pkg.Name -PassThru
      } else {
        Write-Verbose -Message ' moving on ...'
      }
      Write-Verbose -Message ' # # # Next Module # # #'
    }
  }
} # end Find-UpdatedDSCResource

Write-Output -InputObject ' Try Find-UpdatedDSCResource'

Write-Verbose -Message 'Declaring function Find-NewGalleryModule'
function Find-NewGalleryModule {
  Find-Module -Repository PSGallery |
  Where-Object -FilterScript {$PSItem.Tags -NotLike 'DscResource'} |
  Sort-Object -Descending -Property PublishedDate |
  Select-Object -First 30 |
  Format-List -Property Name, PublishedDate, Description, Version |
  Out-Host -Paging
} # end Find-NewGalleryModule

Write-Output -InputObject ' Try Find-NewGalleryModule'
