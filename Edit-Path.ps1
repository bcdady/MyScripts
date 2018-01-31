#!/usr/local/bin/powershell
#Requires -Version 2

[CmdletBinding()]
Param()
Set-StrictMode -Version latest

#Region MyScriptInfo
  Write-Verbose -Message '[Edit-EnvPath] Populating $MyScriptInfo'
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
  Write-Verbose -Message '[Edit-EnvPath] $MyScriptInfo populated'
#End Region

<#
    .SYNOPSIS
    Edit the System PATH statement globally in Windows Powershell with 4 new Advanced functions. Add-EnvPath, Set-EnvPath, Remove-EnvPath, Get-EnvPath - SUPPORTS -whatif parameter
    .DESCRIPTION
    Adds four new Advanced Functions to allow the ability to edit and Manipulate the System PATH ($Env:Path) from Windows Powershell - Must be run as a Local Administrator
    .EXAMPLE
    PS C:\> Get-EnvPathFromRegistry
    Get Current Path
    .EXAMPLE
    PS C:\> Add-EnvPath C:\Foldername
    Add Folder to Path
    .EXAMPLE
    PS C:\> Remove-EnvPath C:\Foldername
    Remove C:\Foldername from the PATH
    .EXAMPLE
    PS C:\> Set-EnvPath C:\Foldernam;C:\AnotherFolder
    Set the current PATH to the above.  WARNING- ERASES ORIGINAL PATH
    .NOTES
    NAME        :  Set-EnvPath
    VERSION     :  1.0   
    LAST UPDATED:  2/20/2015
    AUTHOR      :  Sean Kearney
    # Added 'Test-LocalAdmin' function written by Boe Prox to validate is PowerShell prompt is running in Elevated mode
    # Removed lines for correcting path in Add-EnvPath
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
	
Write-Verbose -Message 'Declaring [Global] Function Set-EnvPath'
Function GLOBAL:Set-EnvPath {
    [Cmdletbinding(SupportsShouldProcess)]
    param (
        [parameter(Mandatory, 
            ValueFromPipeline,
            Position = 0)]
        [Alias('Path','Folder')]
        [String[]]$NewPath
    )

    # Clean up potential garbage in New Path ($AddedFolder)
    $NewPath = $NewPath.replace(';;',';')

    If ( -not (Test-LocalAdmin) ) {
        # Set / override the Environment Path for this session via variable
        if ( $PSCmdlet.ShouldProcess($NewPath) ) {
            $Env:PATH = $NewPath
            # Show what we just did
            Return $NewPath
        }
    } else {
        # Set / override the Environment Path permanently, via registry
        if ( $PSCmdlet.ShouldProcess($NewPath) ) {
            Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH –Value $NewPath -
            # Show what we just did
            Return $NewPath
        }
    }
}

Write-Verbose -Message 'Declaring [Global] Function Add-EnvPath'
Function GLOBAL:Add-EnvPath {
    [Cmdletbinding(SupportsShouldProcess)]
    param (
	    [parameter(Mandatory, 
	        ValueFromPipeline,
	        Position = 0)]
        [Alias('Path','Folder')]
	    [String[]]$AddedFolder
	)

    # See if a new Folder has been supplied
    If (-not $AddedFolder) {
        Write-Warning -Message 'No folder specified. $Env:PATH Unchanged'
        Return $False
    }

    # See if the new Folder exists on the File system
    If (-not (Test-Path $AddedFolder -PathType Container)) {
        Write-Warning -Message 'Folder (specified by Parameter) is not a Directory or was not found; Cannot be added to $Env:PATH'
        Return $False
    }

    If (Test-LocalAdmin) {
        # Get the Current Search Path from the Environment keys in the Registry
        # Make this more REG_EXPAND_SZ friendly -- see https://www.sepago.com/blog/2013/08/22/reading-and-writing-regexpandsz-data-with-powershell
        #$OldPath = (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).Path
        $OldPath = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("System\CurrentControlSet\Control\Session Manager\Environment").GetValue("PATH",$False, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    } else {
        # Get the Environment Path for this session via variable
        $OldPath = $Env:PATH
    }

    # Clean up duplicates and potential garbage from 'Old' Path
    $OldPath = $OldPath.replace(';;',';')
    $OldPath = ($OldPath -Split ';' | Sort-Object -Unique) -join ';'

    # See if the new Folder is already IN the Path
    $PathasArray = ($Env:PATH).split(';')
    If ($PathasArray -contains $AddedFolder -or $PathAsArray -contains $AddedFolder+'\') {
        Write-Verbose -Message 'Folder already within $Env:PATH'
        Return $False
    }

    # If (-not($AddedFolder[-1] -match '\')) {
    #     $Newpath = $Newpath+'\'
    # }

    # Clean up potential garbage in New Path ($AddedFolder)
    $AddedFolder = $AddedFolder.replace(';;',';')
    $AddedFolder = Resolve-Path -Path $AddedFolder

    # Set the New Path
    $NewPath = "$OldPath;$AddedFolder"
    If (Test-LocalAdmin) {
        if ( $PSCmdlet.ShouldProcess($AddedFolder) ) {
            Set-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH –Value $NewPath
            # Show our results back to the world
            Return $NewPath 
        }
    } else {
        # Set / override the Environment Path for this session via variable
        if ( $PSCmdlet.ShouldProcess($NewPath) ) {
            $Env:PATH = $NewPath
            # Show what we just did
            Return $NewPath
        }
    }
}

Write-Verbose -Message 'Declaring [Global] Function Repair-EnvPath'
Function GLOBAL:Repair-EnvPath {
    # Split Path into a unique member array for processing
    $NewPath = $Env:Path.Split(';') | Sort-Object -Unique

    # Replace explicit paths with their Windows expandable variable, and store in a new variable
    $NewPath = $NewPath -replace '\w:\\Program Files \(x86\)','%ProgramFiles(x86)%'
    $NewPath = $NewPath -replace '\w:\\Program Files','%ProgramFiles%'
    $NewPath = $NewPath -replace '\w:\\ProgramData','%ProgramData%'
    $NewPath = $NewPath -replace '\w:\\Windows','%SystemRoot%'

    # Remove any trailing \
    $NewPath = $NewPath -replace '(.+)\\$','$1'

    # Double-check all entries are unique
    $NewPath = $NewPath | Sort-Object -Unique

    # Restore semicolon delimited format
    $NewPath = $NewPath -join ';'

    # Make it so
    Set-EnvPath -Path $NewPath
}

Write-Verbose -Message 'Declaring [Global] Function Get-EnvPath'
Function GLOBAL:Get-EnvPath {
    Return $Env:Path
}

Write-Verbose -Message 'Declaring [Global] Function Get-EnvPathFromRegistry'
Function GLOBAL:Get-EnvPathFromRegistry {
    Return (Get-ItemProperty -Path 'Registry::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\Session Manager\Environment' -Name PATH).Path
}

Write-Verbose -Message 'Declaring [Global] Function Test-EnvPath'
Function GLOBAL:Test-EnvPath {
    [Cmdletbinding()]
    param (
	    [parameter( 
	        ValueFromPipeline,
            Position = 0
        )]
        [Alias('SearchString','String')]
        [String]$Folder
        ,
	    [parameter( 
            Position = 1
        )]
        [Alias('Source')]
	    [Switch]$FromRegistry = $False
    )

    if ($FromRegistry) {
        $VarPath = Get-EnvPathFromRegistry
    } else {
        $VarPath = Get-EnvPath
    }
    # Split Path into a unique member array for processing
    $PathArray = $VarPath.Split(';') | Sort-Object -Unique
    if ($PathArray -like $Folder) {
        Write-Verbose -Message ($PathArray -like $Folder)
        $Result = $True
    } else {
            $Result = $False
    }
        
    Return $Result
}

Write-Verbose -Message 'Declaring [Global] Function Remove-EnvPath'
Function GLOBAL:Remove-EnvPath {
    [Cmdletbinding(SupportsShouldProcess)]
    param (
        [parameter(Mandatory, 
            ValueFromPipeline,
            Position = 0)]
        [Alias('Path','Folder')]
        [String[]]$RemovedFolder
    )

    If ( -not (Test-LocalAdmin) ) { Write-Warning -Message 'Required Administrator permissions not available.'; Return $False }
	
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
