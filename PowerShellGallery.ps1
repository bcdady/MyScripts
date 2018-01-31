#requires -Version 3 -Module PSLogger
#===============================================================================
# NAME      : PowerShellGallery.ps1
# LANGUAGE  : Windows PowerShell
# AUTHOR    : Bryan Dady
# DATE      : 11/29/2017
# COMMENT   : PowerShell functions for interacting with PowerShell Gallery (PowerShellGallery.com) resources
#===============================================================================
[CmdletBinding(SupportsShouldProcess)]
param ()
Set-StrictMode -Version latest

#Region MyScriptInfo
    Write-Verbose -Message '[PowerShellGallery] Populating $MyScriptInfo'
    $script:MyCommandName = $MyInvocation.MyCommand.Name
    $script:MyCommandPath = $MyInvocation.MyCommand.Path
    $script:MyCommandType = $MyInvocation.MyCommand.CommandType
    $script:MyCommandModule = $MyInvocation.MyCommand.Module
    $script:MyModuleName = $MyInvocation.MyCommand.ModuleName
    $script:MyCommandParameters = $MyInvocation.MyCommand.Parameters
    $script:MyParameterSets = $MyInvocation.MyCommand.ParameterSets
    $script:MyRemotingCapability = $MyInvocation.MyCommand.RemotingCapability
    $script:MyVisibility = $MyInvocation.MyCommand.Visibility

    if (($null -eq $script:MyCommandName) -or ($null -eq $script:MyCommandPath)) {
        # We didn't get a successful command / script name or path from $MyInvocation, so check with CallStack
        Write-Verbose -Message "Getting PSCallStack [`$CallStack = Get-PSCallStack]"
        $CallStack = Get-PSCallStack | Select-Object -First 1
        # $CallStack | Select Position, ScriptName, Command | format-list # FunctionName, ScriptLineNumber, Arguments, Location
        $script:myScriptName = $CallStack.ScriptName
        $script:myCommand = $CallStack.Command
        Write-Verbose -Message "`$ScriptName: $script:myScriptName"
        Write-Verbose -Message "`$Command: $script:myCommand"
        Write-Verbose -Message 'Assigning previously null MyCommand variables with CallStack values'
        $script:MyCommandPath = $script:myScriptName
        $script:MyCommandName = $script:myCommand
    }

    #'Optimize New-Object invocation, based on Don Jones' recommendation: https://technet.microsoft.com/en-us/magazine/hh750381.aspx
    $Private:properties = [ordered]@{
        'CommandName'        = $script:MyCommandName
        'CommandPath'        = $script:MyCommandPath
        'CommandType'        = $script:MyCommandType
        'CommandModule'      = $script:MyCommandModule
        'ModuleName'         = $script:MyModuleName
        'CommandParameters'  = $script:MyCommandParameters.Keys
        'ParameterSets'      = $script:MyParameterSets
        'RemotingCapability' = $script:MyRemotingCapability
        'Visibility'         = $script:MyVisibility
    }
    $script:MyScriptInfo = New-Object -TypeName PSObject -Property $properties
    Write-Verbose -Message '[PowerShellGallery] $MyScriptInfo populated'
#End Region

Write-Verbose -Message 'Declaring function Find-UpdatedDSCResource'
function Find-UpdatedDSCResource {
  $MyDSCModules = Get-InstalledModule | Where-Object -FilterScript {($PSItem.Tags -like 'DSC') -and ($PSItem.CompanyName -eq 'PowerShellTeam') -or ($PSItem.Author -like 'Microsoft') } | Select-Object -Property Name, Version

  Write-Output -InputObject 'Checking PowerShellGallery for new or updated DSC Resources (from Microsoft / PowerShellTeam)'
  Write-Verbose -Message 'Find-Package -ProviderName PowerShellGet -Tag DscResource' # | Format-List -Property Name,Status,Summary'
  #Find-Package -ProviderName PowerShellGet -Tag DscResource | Format-List -Property Name,Status,Summary | Out-Host -Paging
  $DSCResources = Find-Module -Tag DscResource -Repository PSGallery | Where-Object -FilterScript {($PSItem.CompanyName -eq 'PowerShellTeam') -or ($PSItem.Author -like 'Microsoft')}
  foreach ($pkg in $DSCResources) {
    Write-Debug -Message ('{0} -in {1}' -f $pkg.Name, $MyDSCModules.Name)

    if ($pkg.Name -in $MyDSCModules.Name) {
      # Retrieve matching local DSC resource module info
      $thisMod = $MyDSCModules | Where-Object -FilterScript { $PSItem.Name -eq $($pkg.Name) }
      Write-Debug -Message $thisMod
      Write-Debug -Message ($pkg.Version -gt $thisMod.Version)
      if ($pkg.Version -gt $thisMod.Version) {
        #Write-Verbose -Message 
        Write-Output -InputObject ('Update to {0} is available' -f $pkg.Name)
        Write-Output -InputObject ('Local: {0} ; Repository: {1}' -f $thisMod.Version, $pkg.Version)
        Update-Module -Name $($pkg.Name) -Confirm
      }
    } else {
      Write-Output -InputObject 'Reviewing new DSC Resource module packages available from PowerShellGallery'
      $pkg | Format-List -Property Name, Description, Dependencies, PublishedDate
      if ([string](Read-Host -Prompt 'Would you like to install this resource module? [Y/N]') -eq 'y') {
        Write-Verbose -Message ('Installing and importing {0} from PowerShellGallery' -f $pkg.Name)
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
