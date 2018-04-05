#!/usr/local/bin/pwsh
#requires -Version 3
#========================================
# NAME      : Merge-MyPSfiles.ps1
# LANGUAGE  : Windows PowerShell
# AUTHOR    : Bryan Dady
# DATE      : 06/12/2016
# COMMENT   : PowerShell script to accelerate interaction with Merge-Repository function - part of Edit-Module
#========================================
[CmdletBinding(SupportsShouldProcess)]
param ()
Set-StrictMode -Version latest

#Region MyScriptInfo
    Write-Verbose -Message '[Merge-MyPSFiles] Populating $MyScriptInfo'
    $Private:MyCommandName        = $MyInvocation.MyCommand.Name
    $Private:MyCommandPath        = $MyInvocation.MyCommand.Path
    $Private:MyCommandType        = $MyInvocation.MyCommand.CommandType
    $Private:MyCommandModule      = $MyInvocation.MyCommand.Module
    $Private:MyModuleName         = $MyInvocation.MyCommand.ModuleName
    $Private:MyCommandParameters  = $MyInvocation.MyCommand.Parameters
    $Private:MyParameterSets      = $MyInvocation.MyCommand.ParameterSets
    $Private:MyRemotingCapability = $MyInvocation.MyCommand.RemotingCapability
    $Private:MyVisibility         = $MyInvocation.MyCommand.Visibility

    if (($null -eq $Private:MyCommandName) -or ($null -eq $Private:MyCommandPath)) {
        # We didn't get a successful command / script name or path from $MyInvocation, so check with CallStack
        Write-Verbose -Message "Getting PSCallStack [`$CallStack = Get-PSCallStack]"
        $Private:CallStack        = Get-PSCallStack | Select-Object -First 1
        $Private:MyScriptName     = $Private:CallStack.ScriptName
        $Private:MyCommand        = $Private:CallStack.Command
        Write-Verbose -Message ('$ScriptName: {0}' -f $Private:MyScriptName)
        Write-Verbose -Message ('$Command: {0}' -f $Private:MyCommand)
        Write-Verbose -Message 'Assigning previously null MyCommand variables with CallStack values'
        $Private:MyCommandPath    = $Private:MyScriptName
        $Private:MyCommandName    = $Private:MyCommand
    }

    #'Optimize New-Object invocation, based on Don Jones' recommendation: https://technet.microsoft.com/en-us/magazine/hh750381.aspx
    $Private:properties = [ordered]@{
        'CommandName'        = $Private:MyCommandName
        'CommandPath'        = $Private:MyCommandPath
        'CommandType'        = $Private:MyCommandType
        'CommandModule'      = $Private:MyCommandModule
        'ModuleName'         = $Private:MyModuleName
        'CommandParameters'  = $Private:MyCommandParameters.Keys
        'ParameterSets'      = $Private:MyParameterSets
        'RemotingCapability' = $Private:MyRemotingCapability
        'Visibility'         = $Private:MyVisibility
    }
    # $Script:MyScriptInfo = New-Object -TypeName PSObject -Property $Private:properties
    New-Variable -Name MyScriptInfo -Value (New-Object -TypeName PSObject -Property $Private:properties) -Scope Local -Option AllScope -Force
    # Cleanup
    foreach ($var in $Private:properties.Keys) {
        Remove-Variable -Name ('My{0}' -f $var) -Force
    }

    $IsVerbose = $false
    if ('Verbose' -in $PSBoundParameters.Keys) {
        Write-Verbose -Message 'Output Level is [Verbose]. $MyScriptInfo is:'
        $MyScriptInfo
        Set-Variable -Name IsVerbose -Value $true -Option AllScope
    }
    Write-Verbose -Message '[Merge-MyPSFiles] $MyScriptInfo populated'
#End Region

# Clean Up this script's Variables. When this script is loaded (dot-sourced), we clean up Merge-MyPSFiles specific variables to ensure they're current when the next function is invoked
('MyMergeSettings', 'DiffTool', 'DiffToolArgs', 'MergeEnvironmentSet', 'netPSHome') | ForEach-Object {
  # Cleanup any Private Scope residue
  if (Get-Variable -Name $PSItem -Scope Private -ErrorAction Ignore) {
    Write-Verbose -Message ('Remove-Variable $Private:{0}' -f $PSItem)
    Remove-Variable -Name $PSItem -Scope Private
  }
  # Cleanup any Local Scope residue
  if (Get-Variable -Name $PSItem -Scope Local -ErrorAction Ignore) {
    Write-Verbose -Message ('Remove-Variable $Local:{0}' -f $PSItem)
    Remove-Variable -Name $PSItem -Scope Local
  }
  # Cleanup any Script Scope residue
  if (Get-Variable -Name $PSItem -Scope Script -ErrorAction Ignore) {
    Write-Verbose -Message ('Remove-Variable $Script:{0}' -f $PSItem)
    Remove-Variable -Name $PSItem -Scope Script
  }
} # End Clean Up

# Declare shared variables, to be available across/between functions
New-Variable -Name MySettingsFile -Description 'Path to Merge-MyPSFiles settings file' -Value 'MyPSfiles.json' -Scope Local -Option AllScope -Force
New-Variable -Name MyMergeSettings -Description ('Settings, from {0}' -f $MySettingsFile) -Scope Local -Option AllScope -Force
New-Variable -Name MergeEnvironmentSet -Description 'Boolean indicating custom environmental variables are loaded / available' -Value $false -Scope Local -Option AllScope -Force

<#
    $Private:CompareDirectory = Join-Path -Path $(Split-Path -Path $PSCommandPath -Parent) -ChildPath 'Compare-Directory.ps1' -ErrorAction Stop
    Write-Verbose -Message (' Dot-Sourcing {0}' -f $Private:CompareDirectory)
    . $Private:CompareDirectory
#>

# Get Merge-MyPSFiles config from Merge-MyPSFiles.json
Write-Verbose -Message 'Declaring Function Import-MyMergeSettings'
Function Import-MyMergeSettings {
    [CmdletBinding()]
    param(
        [Parameter(Position = 1)]
        [switch]
        $ShowSettings
    )
    <#
        "`n # variables in Global scope #"
        get-variable -scope Global

        "`n # variables in Local scope #"
        get-variable -scope Local

        "`n # variables in Script scope #"
        get-variable -scope Script

        "`n # variables in Private scope #"
        get-variable -scope Private
    #>
    
    Write-Debug -Message ('$DSPath = Join-Path -Path {0} -ChildPath {1}' -f (Split-Path -Path $PSCommandPath -Parent), $MySettingsFile)

    $DSPath = Join-Path -Path $(Split-Path -Path $PSCommandPath -Parent) -ChildPath $MySettingsFile
    Write-Debug -Message ('$MyMergeSettings = (Get-Content -Path {0} ) -join "`n" | ConvertFrom-Json' -f $DSPath)

    #try {
    $MyMergeSettings = (Get-Content -Path $DSPath) -join "`n" | ConvertFrom-Json #-ErrorAction Stop
    #}
    #catch {
    if ($?) {
        Write-Verbose -Message 'Settings imported to $MyMergeSettings.' 
    } else {
        throw ('[Import-MyMergeSettings]: Critical Error loading settings from from {0}' -f $DSPath)
    }

    if ($MyMergeSettings) {
        $MyMergeSettings | Add-Member -NotePropertyName imported -NotePropertyValue (Get-Date -UFormat '%m-%d-%Y') -Force
        $MyMergeSettings | Add-Member -NotePropertyName SourcePath -NotePropertyValue $DSPath -Force

        if ($IsVerbose -or $ShowSettings) {
            Write-Output -InputObject ' [Verbose] $MyMergeSettings:' | Out-Host
            Write-Output -InputObject $MyMergeSettings | Out-Host
        }
    }

} # end function Import-MyMergeSettings

Write-Verbose -Message 'Declaring Function Get-Environment'
function Get-Environment {
  [CmdletBinding(SupportsShouldProcess)]
  param ()

  if (Get-Variable -Name myPSLogPath -ErrorAction Ignore) {
    Write-Verbose -Message ('Logging previously initialized. $myPSLogPath: {0}' -f $myPSLogPath)
  } else {
    Write-Verbose -Message '[Bootstrap] Initialize PowerShell Custom Environment Variables.'
    # Load/invoke bootstrap
    if (Test-Path -Path (Join-Path -Path $myPSHome -ChildPath 'bootstrap.ps1')) {
      . (Join-Path -Path $myPSHome -ChildPath 'bootstrap.ps1')

      if (Get-Variable -Name 'myPS*' -ValueOnly -ErrorAction Ignore) {
        Write-Output -InputObject ''
        Write-Output -InputObject 'My PowerShell Environment:'
        Get-Variable -Name 'myPS*' | Format-Table
      } else {
        Write-Warning -Message ('Failed to enumerate My PowerShell Environment as should have been initialized by bootstrap script: {0}'-f (Join-Path -Path $myPSHome -ChildPath 'bootstrap.ps1'))
      }
    } else {
      throw ('Failed to bootstrap: {0}\bootstrap.ps1' -f $myPSHome)
    }
    Write-Verbose -Message ('Logging initialized. $myPSLogPath: {0}' -f $myPSLogPath)
  }

  if ($myPSHome -match "$env:SystemDrive") {
    Write-Verbose -Message ('Set $localPSHome to {0}' -f $myPSHome)
    #$localPSHome = $myPSHome
    Set-Variable -Name localPSHome -Value $myPSHome -Scope Local
  } else {
    $localPSHome = Join-Path -Path $env:USERPROFILE -ChildPath '*Documents\WindowsPowerShell' -Resolve
    Set-Variable -Name localPSHome -Value $localPSHome -Scope Local
  }

  # If %HOMEDRIVE% does not match %SystemDrive%, then it's a network drive, so use that 
  if ($env:HOMEDRIVE -ne $env:SystemDrive) {
    if (Test-Path -Path $env:HOMEDRIVE) {
      $netPSHome = (Join-Path -Path $env:HOMEDRIVE -ChildPath '*\WindowsPowerShell' -Resolve)
      Write-Verbose -Message ('Set $netPSHome to {0}' -f $netPSHome)
      Set-Variable -Name netPSHome -Value $netPSHome -Scope Local
    } else {
      Write-Warning -Message 'Test-Path -Path $env:HOMEDRIVE: $false'
    }
  } else {
    Write-Warning -Message '($env:HOMEDRIVE -ne $env:SystemDrive): $false'
  }

  Set-Variable -Name MergeEnvironmentSet -Description 'Boolean indicating custom environmental variables are loaded / available' -Value $true
} # end function Get-Environment

Write-Verbose -Message 'Declaring Function Merge-MyPSFiles'
function Merge-MyPSFiles {
    [CmdletBinding(SupportsShouldProcess)]
    param()

    if ($MyMergeSettings -and ($MyMergeSettings.imported)) {
        Write-Verbose -Message ('{0} already instantiated.' -f $MyMergeSettings)
    } else {
        Write-Verbose -Message ('Read configs from {0} to $MyMergeSettings' -f $MySettingsFile)
        Import-MyMergeSettings
    }

    if ($MergeEnvironmentSet) {
        Write-Verbose -Message 'Merge-MyPSFiles environmental variables already instantiated.'
    } else {
        Write-Verbose -Message 'Load custom environmental variables with Get-Environment function'
        Get-Environment
    }

    # Specifying the logFile name now explicitly updates the datestamp on the log file
    $logFile = $(Join-Path -Path $myPSLogPath -ChildPath ('{0}-{1}.log' -f $($MyScriptInfo.CommandName.Split('.'))[0], (Get-Date -UFormat '%Y%m%d')))
    Write-Output -InputObject '' | Tee-Object -FilePath $LogFile -Append
    Write-Verbose -Message (' # Logging to {0}' -f $LogFile)
    Write-Output -InputObject ('{0} # Starting Merge-MyPSFiles' -f (Get-Date -Format g)) | Tee-Object -FilePath $logFile -Append

    $MyRepositories = $MyMergeSettings | Select-Object -ExpandProperty RepositorySets
    Write-Verbose -Message ('MyRepositories: {0} ' -f $MyRepositories)

    ForEach ($repo in $MyRepositories) {
        Write-Debug -Message ('$repo.SourcePath: {0}' -f $repo.SourcePath)
        Write-Debug -Message ('$repo.TargetPath: {0}' -f $repo.TargetPath)
        $SourcePath = $ExecutionContext.InvokeCommand.ExpandString($repo.SourcePath)
        $TargetPath = $ExecutionContext.InvokeCommand.ExpandString($repo.TargetPath)
        Write-Verbose -Message ('$Source: {0}' -f $SourcePath)
        Write-Verbose -Message ('$Target: {0}' -f $TargetPath)

        Write-Output -InputObject ('Merging {0}' -f $repo.Name) | Tee-Object -FilePath $logFile -Append
        Write-Verbose -Message ('[bool](Compare-Directory -ReferenceDirectory {0} -DifferenceDirectory {1} -ExcludeFile *.orig,.git*,.hg*,*.md,*.tests.*)' -f $SourcePath, $TargetPath)

        $Private:GoodSource = $false
        $Private:GoodTarget = $false
        # Test availability of SourcePath, and if missing, re-try Mount-Path function
        if (Test-Path -Path $SourcePath) {
            Write-Verbose -Message ('Confirmed source $SourcePath: {0} is available.' -f $SourcePath)
            $Private:GoodSource = $true
        } else {
            # Show warning message
            Write-Warning -Message ('Source ''{0}'' is NOT available.' -f (Split-Path -Path $TargetPath -Parent ))
            # Invoke Mount-Path function, from Sperry module, to map all user's drives
            #Mount-Path
        }

        # Test availability of TargetPath
        if (Test-Path -Path (Split-Path -Path $TargetPath -Parent)) {
            Write-Verbose -Message ('Confirmed TargetPath (parent): {0} is available.' -f (Split-Path -Path ($TargetPath) -Parent))
            $Private:GoodTarget = $true
        } else {
            # Show warning message
            Write-Warning -Message ('Target ''{0}'' is NOT available.' -f (Split-Path -Path $TargetPath -Parent ))
            <#
                # Invoke Mount-Path function, from Sperry module, to map all user's drives
                #Mount-Path
                # Re-Test availability of TargetPath, and if still missing, halt
                if (Test-Path -Path (Split-Path -Path $TargetPath -Parent)) {
	                Write-Verbose -Message ('Confirmed TargetPath (parent): {0} is available.' -f (Split-Path -Path ($TargetPath) -Parent))
	                $Private:GoodToGo = $true
	            } else {
	                # Invoke Mount-Path function, from Sperry module, to map all user's drives
	                Write-Warning -Message 'TargetPath (parent) is still NOT available.'
	            }
			#>
        }

        if ($Private:GoodSource -and $Private:GoodTarget) {
            # Compare Directories (via contained file hashes) before sending to Merge-Repository
            Write-Verbose -Message ('Compare-Directory -ReferenceDirectory {0} -DifferenceDirectory {1}' -f $SourcePath, $TargetPath)
            $Private:DirectoryMatch = (Compare-Directory -ReferenceDirectory $SourcePath -DifferenceDirectory $TargetPath -ExcludeFile '*.orig','.git*','.hg*','*.md','*.tests.*')
            Write-Verbose -Message ('Compare-Directory results in Source/Destination Match? : {0}' -f $Private:DirectoryMatch)
            # if (Compare-Directory -ReferenceDirectory $($SourcePath) -DifferenceDirectory $($TargetPath) -ExcludeFile "*.orig",".git*",".hg*","*.md","*.tests.*") {
            if ($Private:DirectoryMatch) {
                Write-Verbose -Message 'No differences detected ... Skipping merge.'
            } else {
                Write-Verbose -Message 'Compare-Directory function indicates differences detected between repositories. Proceeding with Merge-Repository.'
                Write-Verbose -Message ('Merge-Repository -SourcePath {0} -TargetPath {1} -Recurse' -f $SourcePath, $TargetPath) | Tee-Object -FilePath $logFile -Append
                Merge-Repository -SourcePath $SourcePath -TargetPath $TargetPath -Recurse
            } # end if Compare-Directory
        } else {
            Write-Output -InputObject ''
            Write-Warning -Message 'Fatal Error validating source Path and target Destination'
            Write-Verbose -Message ('$Private:GoodSource: {0} // $Private:GoodTarget: {1}' -f $Private:GoodSource, $Private:GoodTarget)
        }
        Write-Output -InputObject ''
    }
  #EndRegion

  Write-Output -InputObject ('{0} # Ending Merge-MyPSFiles' -f (Get-Date -Format g)) | Tee-Object -FilePath $logFile -Append
  # ======== THE END ======================
  #Write-Output -InputObject "`n # # # Next: Commit and Sync! # # #`n"
  #    Write-Output -InputObject '' | Tee-Object -FilePath $logFile -Append
} # end function Merge-MyPSFiles

Write-Verbose -Message 'Declaring Function Merge-Modules'
function Merge-Modules {
  # Copy or synchronize latest PowerShell Modules folders between a 'local' and a shared path
  [CmdletBinding(SupportsShouldProcess)]
  param()

  if (-not [bool](Get-Variable -Name MyMergeSettings -ErrorAction Ignore)) {
    Write-Verbose -Message ('Reading configs from {0}' -f $MySettingsFile)
    Import-MyMergeSettings
  }

  if (-not $MergeEnvironmentSet) {
    Write-Verbose -Message 'Load custom environmental variables with Get-Environment function'
    Get-Environment
  }

  # Specifying the logFile name now explicitly updates the date stamp on the log file
  $logFile = $(Join-Path -Path $myPSLogPath -ChildPath ('{0}-{1}.log' -f $($MyScriptInfo.CommandName.Split('.'))[0], (Get-Date -UFormat '%Y%m%d')))
  Write-Output -InputObject '' | Tee-Object -FilePath $logFile -Append
  Write-Verbose -Message (' # Logging to {0}' -f $logFile)
  Write-Output -InputObject ('{0} # Starting Merge-Modules' -f (Get-Date -Format g)) | Tee-Object -FilePath $logFile -Append

  # EXAMPLE   : PS .\> .\Merge-MyPSFiles.ps1 -SourcePath .\Modules\ProfilePal -TargetPath ..\GitHub\
  # Technically, per kdiff3 Help, the name of the directory-to-be-merged only needs to be specified once, when the all are the same, just at different root paths.

  $MyModuleNames = $MyMergeSettings | Select-Object -ExpandProperty RepositorySets | ForEach-Object {$_.Name.split('_')[1]} | Sort-Object -Unique
  Write-Debug -Message ('$MyModuleNames: {0}' -f $MyModuleNames)
  $3PModules = Get-Module -ListAvailable -Refresh | Where-Object -FilterScript {($PSItem.Name -notin $MyModuleNames) -and ($PSItem.Path -notlike '*system32*')} | Select-Object -Unique -Property Name,ModuleBase
  Write-Debug -Message ('$3PModules: {0}' -f $3PModules)

  # *** update design to be considerate of branch bandwidth when copying from local to H:, but optimize for performance when copying in NAS
  if (-not [bool](Get-Variable -Name onServer -Scope Global -ErrorAction Ignore)) {
    $Global:onServer = $false
    if ((Get-WmiObject -Class Win32_OperatingSystem -Property Caption).Caption -like '*Windows Server*') {
      [bool]$Global:onServer = $true
    }
  }

  #Region Merge Modules
  # Declare root path of where modules should be merged To
  $ModulesRepo = 'R:\IT\repo\Modules'
  if (Test-Path -Path $ModulesRepo -ErrorAction 'Ignore') {

    foreach ($module in $3PModules) {
      # Robocopy /MIR instead of  merge ... no need to merge 3rd party modules
      $rcSource = $module.ModuleBase
      # Exclude updating system managed / SystemDrive  modules
      if ($rcSource -like "$env:SystemDrive*") {
        Write-Verbose -Message ('Skipping System module update: {0}' -f $module.Name) | Tee-Object -FilePath $logFile -Append
      } else {
        $rcTarget = $(join-path -Path $ModulesRepo -ChildPath $module.Name)
        Write-Verbose -Message ('Preparing to merge module: {0}' -f $module.Name) | Tee-Object -FilePath $logFile -Append
        Write-Verbose -Message ('$rcTarget: {0}' -f $rcTarget) | Tee-Object -FilePath $logFile -Append

        Write-Output -InputObject ('Preparing to mirror {0} (from {1} to {2})' -f $module.Name, $rcSource, $rcTarget) | Tee-Object -FilePath $logFile -Append
                
        # To test these paths, we first need to determine if there are spaces in the path string, which need to be escaped
        Write-Debug -Message ('(Test-Path -Path {0})' -f $rcSource)
        Write-Debug -Message $(Test-Path -Path $rcSource)

        Write-Debug -Message ('(Test-Path -Path {0})' -f $rcTarget)
        Write-Debug -Message $(Test-Path -Path $rcTarget)

        #if ((Test-Path -Path $rcSource) -or (Test-Path -Path $rcTarget)) {
        if (Test-Path -Path $rcSource) {
          # robocopy.exe writes wierd characters, if/when we let it share, so robocopy gets it's own log file
          #$RCLogFile = $(Join-Path -Path $myPSLogPath -ChildPath ('{0}-robocopy-{1}.log' -f $($MyScriptInfo.CommandName.Split('.'))[0], (Get-Date -UFormat '%Y%m%d')))
          Write-Verbose -Message ('[Merge-Modules] Update-Repository {0} Source: {1} Destination: {2}' -f $module.Name, $rcSource, $rcTarget) | Tee-Object -FilePath $logFile -Append
          Update-Repository -Name $module.Name -Path $rcSource -Destination $rcTarget

          <# repeat robocopy to PowerShell-Modules repository
              $rcTarget = ('\\hcdata\apps\IT\PowerShell-Modules\{0}' -f $module.Name)
              Write-Verbose -Message ('[Merge-Modules] Updating {0} from {1} to {2}' -f $module.Name, $rcSource, $rcTarget) | Tee-Object -FilePath $logFile -Append
              Update-Repository -Name $module.Name -Path $rcSource -Destination $rcTarget
              #Start-Process -FilePath robocopy.exe -ArgumentList "$rcSource \\hcdata\apps\IT\PowerShell-Modules\$module /MIR /TEE /LOG+:$RCLogFile /R:1 /W:1 /NP /TS /FP /DCOPY:T /DST /XD .git /XF .gitattributes /NJH" -Wait -Verb open
          #>
        } else {
          Write-Warning -Message ('Failed to confirm paths; {0} OR {1}' -f $rcSource, $rcTarget)
        }
      }
    }
  } else {
    Write-Warning -Message ('Unable to confirm availability of Path: {0}' -f $ModulesRepo)
  }
  #End Region

  Write-Output -InputObject ''
  Write-Output -InputObject ('{0} # Ending Merge-Modules' -f (Get-Date -Format g)) | Tee-Object -FilePath $logFile -Append
  Write-Output -InputObject ''
  
  # ======== THE END ======================
} # end function Merge-Modules
