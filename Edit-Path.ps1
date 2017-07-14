#!/usr/local/bin/powershell
#Requires -Version 2

[CmdletBinding()]
Param()
Set-StrictMode -Version latest

#Region MyScriptInfo
  Write-Verbose -Message '[Edit-Path] Populating $MyScriptInfo'
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
  $MyScriptInfo = New-Object -TypeName PSObject -Prop $properties
  Write-Verbose -Message '[Edit-Path] $MyScriptInfo populated'
#End Region

<#
    .SYNOPSIS
    Edit the System PATH statement globally in Windows Powershell with 4 new Advanced functions. Add-path, Set-path, Remove-path, Get-path - SUPPORTS -whatif parameter
    .DESCRIPTION
    Adds four new Advanced Functions to allow the ability to edit and Manipulate the System PATH ($Env:Path) from Windows Powershell - Must be run as a Local Administrator
    .EXAMPLE
    PS C:\> Get-PathFromRegistry
    Get Current Path
    .EXAMPLE
    PS C:\> ADD-PATH C:\Foldername
    Add Folder to Path
    .EXAMPLE
    PS C:\> Remove-Path C:\Foldername
    Remove C:\Foldername from the PATH
    .EXAMPLE
    PS C:\> Set-Path C:\Foldernam;C:\AnotherFolder
    Set the current PATH to the above.  WARNING- ERASES ORIGINAL PATH
    .NOTES
    NAME        :  Set-Path
    VERSION     :  1.0   
    LAST UPDATED:  2/20/2015
    AUTHOR      :  Sean Kearney
    # Added 'Test-LocalAdmin' function written by Boe Prox to validate is PowerShell prompt is running in Elevated mode
    # Removed lines for correcting path in ADD-PATH
    # Switched Path search to an Array for "Exact Match" searching
    # 2/20/2015
    .LINK
    https://gallery.technet.microsoft.com/3aa9d51a-44af-4d2a-aa44-6ea541a9f721
    .LINK
    Test-LocalAdmin 
    .INPUTS
    None
    .OUTPUTS
    None
#>

Write-Verbose -Message 'Declaring [Global] Function Test-LocalAdmin'
Function GLOBAL:Test-LocalAdmin {
	Return ([security.principal.windowsprincipal] [security.principal.windowsidentity]::GetCurrent()).isinrole([Security.Principal.WindowsBuiltInRole] 'Administrator')
}
	
Write-Verbose -Message 'Declaring [Global] Function Set-Path'
Function GLOBAL:Set-Path {
    [Cmdletbinding(SupportsShouldProcess)]
    param (
        [parameter(Mandatory, 
            ValueFromPipeline,
            Position = 0)]
        [String[]]$NewPath
    )

    # Clean up potential garbage in New Path ($AddedFolder)
    $AddedFolder = $AddedFolder.replace(';;',';')

    If ( -not (Test-LocalAdmin) ) {
        # Write-Warning -Message 'Need to Run As Administrator first'; Return $False
        # Set / override the Environment Path for this session via variable
        if ( $PSCmdlet.ShouldProcess($NewPath) ) {
            $Env:PATH = $NewPath
            # Show what we just did
            Return $NewPath
        }
    } else {
        # Set / override the Environment Path permanently, via registry
        if ( $PSCmdlet.ShouldProcess($NewPath) ) {
            Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH –Value $NewPath
            # Show what we just did
            Return $NewPath
        }
    }
}

Write-Verbose -Message 'Declaring [Global] Function Add-Path'
Function GLOBAL:Add-Path {
    [Cmdletbinding(SupportsShouldProcess)]
    param (
	    [parameter(Mandatory, 
	        ValueFromPipeline,
	        Position = 0)]
        [Alias('Path')]
	    [String[]]$AddedFolder
	)

    # Get the Current Search Path from the Environment keys in the Registry
    $OldPath = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).Path

    # Clean up potential garbage from 'Old' Path
    $OldPath = $OldPath.replace(';;',';')

    # Clean up potential garbage in New Path ($AddedFolder)
    $AddedFolder = $AddedFolder.replace(';;',';')

    # See if a new Folder has been supplied
    If (-not$AddedFolder) {
        Write-Warning -Message 'No Folder Supplied. $Env:PATH Unchanged'
        Return $False
    }

    # See if the new Folder exists on the File system
    If (-not (Test-Path $AddedFolder -PathType Container)) {
        Write-Warning -Message 'Folder (specified by Parameter) does not exist; Cannot be added to $Env:PATH'
        Return $False
    }

    # See if the new Folder is already IN the Path
    $PathasArray = ($Env:PATH).split(';')
    If ($PathasArray -contains $AddedFolder -or $PathAsArray -contains $AddedFolder+'\') {
        Write-Warning -Message 'Folder already within $Env:PATH'
        Return $False
    }

    # If (-not($AddedFolder[-1] -match '\')) {
    #     $Newpath = $Newpath+'\'
    # }

    # Set the New Path
    $NewPath = "$OldPath;$AddedFolder"
    If ( -not (Test-LocalAdmin) ) {
        # Write-Warning -Message 'Need to RUN AS ADMINISTRATOR first'; Return $False }
        # Set / override the Environment Path for this session via variable
        if ( $PSCmdlet.ShouldProcess($NewPath) ) {
            $Env:PATH = $NewPath
            # Show what we just did
            Return $NewPath
        }
    } else {
        if ( $PSCmdlet.ShouldProcess($AddedFolder) ) {
            Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH –Value $NewPath
            # Show our results back to the world
            Return $NewPath 
        }
    }
}

Write-Verbose -Message 'Declaring [Global] Function Get-PathFromRegistry'
Function GLOBAL:Get-PathFromRegistry {
    Return (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).Path
}

Write-Verbose -Message 'Declaring [Global] Function Remove-Path'
Function GLOBAL:Remove-Path {
    [Cmdletbinding(SupportsShouldProcess)]
    param (
        [parameter(Mandatory, 
            ValueFromPipeline,
            Position = 0)]
        [String[]]$RemovedFolder
    )

    If ( -not (Test-LocalAdmin) ) { Write-Warning -Message 'Need to RUN AS ADMINISTRATOR first'; Return $False }
	
    # Get the Current Search Path from the Environment keys in the Registry
    $OldPath = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).Path

    # Verify item exists as an EXACT match before removing
    If ($Oldpath.split(';') -contains $RemovedFolder) {
        # Find the value to remove, replace it with $NULL.  If it’s not found, nothing will change
        $NewPath = $OldPath.replace($RemovedFolder,$NULL)
    }

    # Clean up any potential garbage from Path
    $Newpath = $NewPath.replace(';;',';')

    # Update the Environment Path
    if ( $PSCmdlet.ShouldProcess($RemovedFolder) ) {
        Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH –Value $NewPath

        # Show what we just did
        Return $NewPath
    }
}
