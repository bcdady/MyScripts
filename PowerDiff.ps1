#requires -Version 3 -Module PSLogger
#===============================================================================
# NAME      : PowerDiff.ps1
# LANGUAGE  : Windows PowerShell
# AUTHOR    : Bryan Dady
# DATE      : 06/12/2016
# COMMENT   : PowerShell script to automate kdiff3.exe
# EXAMPLE   : PS .\> .\PowerDiff.ps1 -SourcePath .\Modules\ProfilePal -TargetPath ..\GitHub\ProfilePal -MergePath 'H:\My Documents\WindowsPowerShell\Modules\ProfilePal'
#===============================================================================
[CmdletBinding(SupportsShouldProcess)]
param ()
Set-StrictMode -Version latest

# Declare shared variable, so that it's available across/between functions
$Local:SettingsFileName = 'powerdiff.json'
Set-Variable -Name PDSettings -Description ('Settings, from {0}' -f $Local:SettingsFileName) -Scope Local -Option Private

#===============================================================================
#Region MyScriptInfo
    Write-Verbose -Message '[PowerDiff] Populating $MyScriptInfo'
    $script:MyCommandName        = $MyInvocation.MyCommand.Name
    $script:MyCommandPath        = $MyInvocation.MyCommand.Path
    $script:MyCommandType        = $MyInvocation.MyCommand.CommandType
    $script:MyCommandModule      = $MyInvocation.MyCommand.Module
    $script:MyModuleName         = $MyInvocation.MyCommand.ModuleName
    $script:MyCommandParameters  = $MyInvocation.MyCommand.Parameters
    $script:MyParameterSets      = $MyInvocation.MyCommand.ParameterSets
    $script:MyRemotingCapability = $MyInvocation.MyCommand.RemotingCapability
    $script:MyVisibility         = $MyInvocation.MyCommand.Visibility

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
    Write-Verbose -Message '[PowerDiff] $MyScriptInfo populated'
#End Region

if (-not [bool](Get-Variable -Name myPSHome -Scope Global -ErrorAction Ignore)) {
    Write-Verbose -Message "Set `$script:myPSHome to $(Join-Path -Path "$([Environment]::GetFolderPath('MyDocuments'))" -ChildPath 'WindowsPowerShell')"
    $script:myPSHome = Join-Path -Path "$([Environment]::GetFolderPath('MyDocuments'))" -ChildPath 'WindowsPowerShell'
}

if ($myPSHome -match "$env:SystemDrive") {
    Write-Verbose -Message "Set `$script:localPSHome to $myPSHome"
    $script:localPSHome = $myPSHome
}
$script:netPSHome = $null

# If %HOMEDRIVE% does not match %SystemDrive%, then it's a network drive, so use that 
if ($env:HOMEDRIVE -ne $env:SystemDrive) {
    if (Test-Path -Path $env:HOMEDRIVE) {
        Write-Verbose -Message "Set `$script:netPSHome to `$env:HOMEDRIVE ($env:HOMEDRIVE)"
        $script:netPSHome = Join-Path -Path $env:HOMEDRIVE -ChildPath '*\WindowsPowerShell' -Resolve
    }
}

if (Get-Variable -Name loggingPath -ErrorAction Ignore) {
    Write-Verbose -Message ('[PSLogger] logging previously initialized. `$loggingPath: {0}' -f $loggingPath)
} else {
    Write-Verbose -Message '[PSLogger] Initialize-Logging.'
    Initialize-Logging
    Write-Verbose -Message ('[PSLogger] Logging initialized. `$loggingPath: {0}' -f $loggingPath)
}
#Derive $logBase from script name. The most reliable automatic variable for this is $MyInvocation.MyCommand.Name
# But the value of this variable changes within Functions, so we define a shared logging base from the 'parent' script file (name) level
# all logging cmdlets later throughout this script should derive their logging path from this $logBase directory, by appending simply .log, or preferable [date].log
$script:logFilePrefix = $($MyScriptInfo.CommandName.Split('.'))[0]

Write-Verbose -Message (' Dot-Sourcing {0}' -f $MyScriptInfo.CommandPath)
Write-Debug -Message ('  ... logname syntax is {0}\{1}-[date].log' -f $loggingPath, $script:logFilePrefix)

# Get PowerDiff config from PowerDiff.json
Write-Verbose -Message 'Declaring Function Import-Settings'
Function Import-Settings {
    [CmdletBinding()]
    <#
        .SYNOPSIS
        Import-Settings loads PowerDiff configurations and preferences from a specified json file, such as powerdiff.json

        .DESCRIPTION
        Moving PowerDiff configurations and preferences out of the script body and into a json file makes the script a bit smaller and easier to maintain.
        It also makes user-specific modifications easier to apply and maintain.
        The settings are saved from the json file definitions to an object variable that can be more quickly and consistently access throughout the functions within PowerDiff.ps1.

        .PARAMETER SettingsFileName
        Specifies the path to the settings file, such as .\powerdiff.json. This can also be defined or modified within PowerDiff.ps1 as $Local:SettingsFileName.

        .PARAMETER PassThru
        PassThru indicates that the imported settings should be displayed in the console output

        .EXAMPLE
        Import-Settings
        Imports and stores the settings as defined in the local powerdiff.json file

        .EXAMPLE
        Import-Settings -SettingsFileName 'my-powerdiff.json' -PassThru
        Imports and stores the settings as defined in .\my-powerdiff.json, and displays 
    #>
    param(
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $SettingsFileName = 'powerdiff.json'
        ,
        [Parameter(Position = 1)]
        [switch]
        $PassThru
    )

  Write-Debug -Message ("`$Script:PDSettings = (Get-Content -Path {0}) -join ""``n"" | ConvertFrom-Json" -f (Join-Path -Path $(Split-Path -Path $PSCommandPath -Parent) -ChildPath $SettingsFileName))
  try {
    $Script:PDSettings = (Get-Content -Path $(Join-Path -Path $(Split-Path -Path $PSCommandPath -Parent) -ChildPath $SettingsFileName)) -join "`n" | ConvertFrom-Json
    Write-Verbose -Message 'Settings imported to $Script:PDSettings.' 
  }
  catch {
    Write-Warning -Message ('Critical Error loading settings from {0}' -f $SettingsFileName)
  }

  if ($Script:PDSettings -and $PassThru) {
    #  Write-Output -InputObject '$Script:PDSettings'
    $Script:PDSettings
  }

  
} # end function Import-Settings

Write-Verbose -Message ('Reading configs from {0}' -f $Local:SettingsFileName)
Import-Settings -SettingsFileName $Local:SettingsFileName

# Define path to local copy of kdiff3.exe
$script:kdiff = $Script:PDSettings.DiffTool.Path

if ( -not (Test-Path -Path $script:kdiff -PathType Leaf)) {
    Write-Warning -Message ('Failed to find kdiff.exe at {0}' -f $script:kdiff)
    break
}
Write-Verbose -Message ('Using diff tool: {0}' -f $script:kdiff)

# Syntax we're going for: kdiff3 dir1 dir2 [dir3] -o destdir
# for additional 'Help' info, browse: file:///C:/Program%20Files/KDiff3/doc/startingdirmerge.html

# Define optional arguments / configs to pass to kdiff3.exe.
# Config Settings (cs) defined here as an array, for easier maintenance; -joined into the $script:kdArgs string below, before being passed in -ArgumentList to kdiff.exe
# For more context, run kdiff3.exe -help and/or kdiff3.exe -confighelp

# 'SkipDirStatus=1', -- removed due to error message

$CompareDirectory = Join-Path -Path $(Split-Path -Path $MyScriptInfo.CommandPath -Parent) -ChildPath 'Compare-Directory.ps1' -ErrorAction Stop
Write-Verbose -Message (' Dot-Sourcing {0}' -f $CompareDirectory)
. $CompareDirectory

Write-Verbose -Message 'Declaring Function Merge-Repository'
function Merge-Repository {
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [Parameter(
          Mandatory = $true,
          HelpMessage='Specify a path to the source file to compare/merge',
          Position = 0
        )]
        [ValidateScript({Test-Path -Path $PSItem})]
        [Alias('SourcePath','A')]
        [string]
        $file1
        ,
        [Parameter(
          Mandatory = $true,
          HelpMessage='Specify a path to the target file to compare/merge',
          Position = 1
        )]
        [ValidateScript({Test-Path -Path $PSItem -IsValid})]
        [Alias('TargetPath','B')]
        [string]
        $file2
        ,
        [Parameter(Position = 2)]
        [ValidateScript({Test-Path -Path $PSItem -IsValid})]
        [Alias('MergePath','C')]
        [string]
        $file3
        ,
        [Parameter(Position = 3)]
        [switch]
        $Recurse
        ,
        [Parameter(Position = 4)]
        [array]
        $Filter
    )
    #region Setup
    $error.clear()
    $ErrorActionPreference = 'Stop' # throw statement requires 'Stop'
    # DEBUG MODE : $ErrorActionPreference = "Inquire"; "`$error = $error[0]"

    # ======== BEGIN ====================
    if ( -not (Test-Path -Path $script:kdiff -PathType Leaf)) {
        throw "`nFatal Error: Failed to find $script:kdiff`n"
    }

    # Build dynamic logging file path at ...\[My ]Documents\WindowsPowershell\log\[scriptname]-[rundate].log
    $script:logFile = $(Join-Path -Path $loggingPath -ChildPath ('{0}-{1}.log' -f $script:logFilePrefix, (Get-Date -UFormat '%Y%m%d')))
    Write-Output -InputObject '' | Tee-Object -FilePath $script:logFile -Append
    Write-Verbose -Message ('Logging to {0}' -f $script:logFile)

    $script:RCLogFile = $(Join-Path -Path $loggingPath -ChildPath "$script:logFilePrefix-robocopy-$(Get-Date -UFormat '%Y%m%d').log")

    Write-Verbose -Message "$(Get-Date -Format g) # Starting Merge-Repository -file1 $file1 -file2 $file2 -file3 $file3" | Tee-Object -FilePath $script:logFile -Append

    $script:kdArgs = ' --merge --auto'+' --cs '+($Script:PDSettings.DiffTool.Options | ForEach-Object {"$($PSItem.Setting)=$($PSItem.Value)"})+''

    if ($Recurse) {
        $script:kdArgs = $script:kdArgs -replace 'RecursiveDirs=0','RecursiveDirs=1'
    }

    Write-Debug -Message "`$script:kdiffConfig is set. `$script:kdArgs: $script:kdArgs" | Tee-Object -FilePath $script:logFile -Append
    try {
        ($null = Test-Path -Path $file1)
    }
    catch {
        Write-Output -InputObject "Error was $_" | Tee-Object -FilePath $script:logFile -Append
        $line = $MyInvocation.ScriptLineNumber | Tee-Object -FilePath $script:logFile -Append
        Write-Output -InputObject "Error was in Line $line" | Tee-Object -FilePath $script:logFile -Append
        Write-Output -InputObject 'file1 (A) not found; nothing to merge.' | Tee-Object -FilePath $script:logFile -Append
    }

    #region File1
    # To handle spaces in paths, for kdiff3, without triggering ValidateScript errors against the functions defined parameters, we copy the function paramters to internal variables
    # kdiff file1 / 'A' = $SourcePath
    # kdiff file2 / 'B' = $TargetPath
    # kdiff file3 / 'C' = $MergePath
    if ($file1.Contains(' ')) {
        Write-Debug -Message "Wrapping `$SourcePath with double-quotes"
        $SourcePath = """$file1"""
    } else {
        $SourcePath = $file1
    }
    #EndRegion

    #region File2
    $ErrorActionPreference = 'stop'

    Write-Debug -Message "Test-Path -Path $file2"

    try {
        ($null = Test-Path -Path $file2)
    }
    catch {
        Write-Output -InputObject "Error was $_" | Tee-Object -FilePath $script:logFile -Append
        $line = $MyInvocation.ScriptLineNumber
        Write-Output -InputObject "Error was in Line $line" | Tee-Object -FilePath $script:logFile -Append
        Write-Output -InputObject 'file2 (B) not found; nothing to merge. Copying via Copy-Item.' | Tee-Object -FilePath $script:logFile -Append
        Copy-Item -Path $file1 -Destination $file2 -Recurse -Confirm | Tee-Object -FilePath $script:logFile -Append
    }
    #EndRegion

    if ($file2.Contains(' ')) {
        Write-Debug -Message "Wrapping `$TargetPath with double-quotes"
        $TargetPath = """$file2"""
    } else {
        $TargetPath = $file2
    }

    #region File2
    if ($file3.Contains(' ')) {
        Write-Debug -Message "Wrapping `$MergePath with double-quotes"
        $MergePath = """$file3"""
    } else {
        $MergePath = $file3
    }
    #EndRegion

    # ======== PROCESS ==================
    #region Merge
    # Show what we're going to run on the console, then actually run it.
    if ([bool]$MergePath) {
        Write-Verbose -Message "Detected MergePath : $MergePath"
        Write-Verbose -Message ('{0} {1} {2} --output {3} {4}' -f $script:kdiff, $SourcePath, $TargetPath, $MergePath, $script:kdArgs)

        if ($PSCmdlet.ShouldProcess($SourcePath,$("Merge $SourcePath, $TargetPath, $MergePath"))) {
            Write-Debug -Message ('[DEBUG] {0} -ArgumentList {1} {2} --output {3} {4}' -f $script:kdiff, $SourcePath, $TargetPath, $MergePath, $script:kdArgs)
            Write-Output -InputObject ("Merging {0} `n: {1} -> {2}" -f $SourcePath, $TargetPath, $MergePath) | Out-File -FilePath $script:logFile -Append
            Start-Process -FilePath $script:kdiff -ArgumentList ('{0} {1} --output {2} {3}' -f $SourcePath, $TargetPath, $MergePath, $script:kdArgs) -Wait | Tee-Object -FilePath $script:logFile -Append
        }

        # In a 3-way merge, kdiff3 only sync's with merged output file. So, after the merge is complete, we copy the final / merged output to the TargetPath directory.
        # Copy-Item considers double-quotes 'Illegal characters in path',  so we use the original $file2, instead of $TargetPath
        Write-Verbose -Message ('Copy-Item -Path {0} -Destination {1} -Recurse -Confirm' -f $MergePath, (Split-Path -Path $file2))
        # Copy-Item -Path $MergePath -Destination $(Split-Path -Path $file2) -Recurse -Confirm

        if ($PSCmdlet.ShouldProcess($MergePath,$("Copy $MergePath via Robocopy"))) {
            Write-Output -InputObject "Mirroring $MergePath back to $(Split-Path -Path $file2) (using Robocopy)" | Tee-Object -FilePath $script:logFile -Append
            if ($null = Test-Path -Path $file2 -PathType Leaf) {
                $rcTarget = $(Split-Path -Path $file2)
            } else {
                $rcTarget = $TargetPath
            }
            Write-Verbose -Message ('robocopy {0} {1} /L /MIR /TEE /MT /NP /TS /FP /DCOPY:T /DST /R:1 /W:1 /XF *.orig /NJH /NS /NC /NP /LOG+:{2}' -f $MergePath, $rcTarget, $script:RCLogFile)
            Write-Output -InputObject ('robocopy {0} {1} /L /MIR /TEE /MT /NP /TS /FP /DCOPY:T /DST /R:1 /W:1 /XF *.orig /NJH /NS /NC /NP /LOG+:{2}' -f $MergePath, $rcTarget, $script:RCLogFile) | Out-File -FilePath $script:logFile -Append
            & "$env:windir\system32\robocopy.exe" $MergePath $rcTarget /L /MIR /TEE /MT /NP /TS /FP /DCOPY:T /DST /R:1 /W:1 /XF *.orig /NJH /NS /NC /NP /LOG+:$script:RCLogFile
        }
    } else {
        Write-Verbose -Message 'No MergePath; 2-way merge'
    # * * * RFE : Move file-hash comparison into a function, so it can handle folder hash comparison
    #            if ( -not [bool](Compare-Object -ReferenceObject (get-filehash -Path $SourcePath) (get-filehash -Path $TargetPath) -Property Hash))
    #            {
            Write-Verbose -Message "$script:kdiff $SourcePath $TargetPath $script:kdArgs"
            if ($PSCmdlet.ShouldProcess($SourcePath,$("Merge $SourcePath, $TargetPath"))) {
                Write-Output -InputObject ('Merging {0} <-> {1}' -f $SourcePath, $TargetPath) | Out-File -FilePath $script:logFile -Append
                Start-Process -FilePath $script:kdiff -ArgumentList ('-b {0} {1}' -f $SourcePath, $TargetPath) -Wait # $script:kdArgs
                # In a 2-way merge, with SyncMode=1 kdiff3 can sync both directories, so we can skip the copy/mirror-back activity of the 3-way merge above.
            }
    }
    #EndRegion

    Write-Output -InputObject "`n$(Get-Date -Format g) # Ending Merge-Repository`n" | Tee-Object -FilePath $script:logFile -Append
    # ======== THE END ======================
    # Write-Output -InputObject '' | Tee-Object -FilePath $script:logFile -Append

}

Write-Verbose -Message 'Declaring Function Merge-MyPSFiles'
function Merge-MyPSFiles {
    [CmdletBinding(SupportsShouldProcess)]
    param ()

    # Specifying the logFile name now explicitly updates the datestamp on the log file
    $script:logFile = $(Join-Path -Path $loggingPath -ChildPath ('{0}-{1}.log' -f $script:logFilePrefix, (Get-Date -UFormat '%Y%m%d')))
    Write-Output -InputObject '' | Tee-Object -FilePath $script:logFile -Append
    Write-Output -InputObject ('logging to {0}' -f $script:logFile)
    Write-Output -InputObject "$(Get-Date -Format g) # Starting Merge-MyPSFiles" | Tee-Object -FilePath $script:logFile -Append

    $MyRepositories = $Script:PDSettings | Select-Object -ExpandProperty RepositorySets

    ForEach ($repo in $MyRepositories) {
        Write-Output -InputObject ('Merging {0}' -f $repo.Name) | Tee-Object -FilePath $script:logFile -Append
        Write-Verbose -Message ('Name: {0}, SourcePath: {1} , TargetPath: {2})' -f $repo.Name, $repo.SourcePath, $repo.TargetPath)

        # The most common expected repo type is a directory, so provide special handling in case the repo being processed is a file / leaf
        $IsFile = $False
        if (Test-Path -Path $repo.SourcePath -PathType Leaf) {
            $IsFile = $True
        }
        # Test availability of SourcePath, and if missing, re-try Mount-Path function
        if (Test-Path -Path $repo.SourcePath) {
            Write-Verbose -Message ('Confirmed source $repo.SourcePath: {0} is available.' -f $repo.SourcePath)
        } else {
            # Invoke Mount-Path function, from Sperry module, to map all user's drives
            Write-Warning -Message ('Source {0} is NOT available ... Running Mount-Path.' -f $repo.SourcePath)
            Mount-Path
        }

        # Test availability of TargetPath, and if missing, re-try Mount-Path function
        $TargetParent = Split-Path -Path $repo.SourcePath -Parent
        if (Test-Path -Path $TargetParent) {
            Write-Verbose -Message ('Confirmed TargetPath (parent): {0} is available.' -f $TargetParent) -E
        } else {
            # Invoke Mount-Path function, from Sperry module, to map all user's drives
            Write-Warning -Message 'TargetPath (parent) is NOT available ... Running Mount-Path.'
            Mount-Path
            # Re-Test availability of TargetPath, and if still missing, halt
            if (Test-Path -Path $TargetParent) {
                Write-Verbose -Message ('Confirmed TargetPath (parent): {0} is available.' -f $TargetParent)
            } else {
                # Invoke Mount-Path function, from Sperry module, to map all user's drives
                throw 'TargetPath (parent) is still NOT available.'
            }
        }

        if ($IsFile) {
            Write-Verbose -Message ('Specified repository is a file; skipping Compare-Directory')
        } else {
            # Compare Directories (via contained file hashes) before sending to Merge-Repository
            Write-Verbose -Message ('[bool](Compare-Directory -ReferenceDirectory {0} -DifferenceDirectory {1} -ExcludeFile ""*.orig"","".git*"","".hg*"",""*.md"",""*.tests.*"")' -f $repo.SourcePath, $repo.TargetPath)
            Write-Verbose -Message ('{0}' -f ([bool](Compare-Directory -ReferenceDirectory $($repo.SourcePath) -DifferenceDirectory $($repo.TargetPath) -ExcludeFile '"*.orig"','".git*"','".hg*"','"*.md"','"*.tests.*"')))
            if (Compare-Directory -ReferenceDirectory {0} -DifferenceDirectory {1} -ExcludeFile '*.orig','.git*','.hg*','*.md','*.tests.*' -f $repo.SourcePath, $repo.TargetPath)) {
                Write-Verbose -Message 'No differences detected ... Skipping merge.'
            } else {
                Write-Verbose -Message 'Compare-Directory function indicates differences detected between repositories. Proceeding with Merge-Repository.'
                Write-Verbose -Message ('Merge-Repository -SourcePath {0} -TargetPath {1}' -f $repo.SourcePath, $repo.TargetPath) | Tee-Object -FilePath $script:logFile -Append
                Merge-Repository -file1 "$($repo.SourcePath)" -file2 "$($repo.TargetPath)"
            } # end if Compare-Directory
        }
    } # End ForEach $MyRepositories
#EndRegion

    Write-Output -InputObject "`n$(Get-Date -Format g) # Ending Merge-MyPSFiles`n" | Tee-Object -FilePath $script:logFile -Append
    # ======== THE END ======================
    Write-Output -InputObject "`n # # # Next: Commit and Sync! # # #`n"
  #    Write-Output -InputObject '' | Tee-Object -FilePath $script:logFile -Append
} # end of function

Write-Verbose -Message 'Declaring Function Merge-Modules'
function Merge-Modules {
    # Copy or synchronize latest PowerShell Modules folders between a 'local' and a shared path
    [CmdletBinding(SupportsShouldProcess)]
    param ()

    # Specifying the logFile name now explicitly updates the date stamp on the log file
    $script:logFile = $(Join-Path -Path $loggingPath -ChildPath ('{0}-{1}.log' -f $script:logFilePrefix, (Get-Date -UFormat '%Y%m%d')))
    Write-Output -InputObject '' | Tee-Object -FilePath $script:logFile -Append
    Write-Output -InputObject "logging to $script:logFile"
    Write-Output -InputObject "$(Get-Date -Format g) # Starting Merge-MyPSFiles" | Tee-Object -FilePath $script:logFile -Append

    # EXAMPLE   : PS .\> .\PowerDiff.ps1 -SourcePath .\Modules\ProfilePal -TargetPath ..\GitHub\
    # Technically, per kdiff3 Help, the name of the directory-to-be-merged only needs to be specified once, when the all are the same, just at different root paths.

    $MyRepositories = $Script:PDSettings | Select-Object -ExpandProperty RepositorySets

    $3PModules = Get-Module -ListAvailable -Refresh | Where-Object -FilterScript {($PSItem.Name -notin $MyRepositories.Name) -and ($PSItem.Path -notlike '*system32*')} | Select-Object -Property Name

    # *** update design to be considerate of branch bandwidth when copying from local to H:, but optimize for performance when copying in NAS
    if (-not [bool](Get-Variable -Name onServer -Scope Global -ErrorAction Ignore)) {
        [bool]$onServer = $false
        if ((Get-WmiObject -Class Win32_OperatingSystem -Property Caption).Caption -like '*Windows Server*') {
            [bool]$Global:onServer = $true
        }
    }

    #Region Merge Modules
    
    # Declare root path of where modules should be merged To
    $ModulesRepo = Join-Path -Path 'R:' -ChildPath 'IT\repo\Modules'

    foreach ($module in $3PModules.Name) {
        # Robocopy /MIR instead of  merge ... no need to merge 3rd party modules
        $script:rcTarget = """$(join-path -Path $ModulesRepo -ChildPath $module)"""
        Write-Verbose -Message "Preparing to merge module: $module" | Tee-Object -FilePath $script:logFile -Append
        Write-Verbose -Message "`$script:rcTarget: $script:rcTarget" | Tee-Object -FilePath $script:logFile -Append
        try {
            Write-Verbose -Message ('Name, ModuleBase: {0}' -f ((Get-Module -ListAvailable -Name $module | Select-Object -Unique) | Select-Object -Property Name,ModuleBase)) | Tee-Object -FilePath $script:logFile -Append
            $script:rcSource = ('""{0}""' -f (Get-Module -ListAvailable -Name $module | Select-Object -Unique).ModuleBase)
            Write-Output -InputObject ('Updating {0} (from {1} to {2} with Robocopy)' -f $module, $script:rcSource, $script:rcTarget) | Tee-Object -FilePath $script:logFile -Append
        }
        catch {
            Write-Warning -Message "Failed to read Module's directory property (ModuleBase)"
        }
        
        # To test these paths, we
        if ((Test-Path -Path $script:rcSource) -and (Test-Path -Path $script:rcTarget)) {
            Write-Verbose -Message ('Robocopying {0} from {1} to {2}' -f $module, $script:rcSource, $script:rcTarget) | Tee-Object -FilePath $script:logFile -Append
            
            # robocopy.exe writes wierd characters, if/when we let it share, so robocopy gets it's own log file
            $script:RCLogFile = $(Join-Path -Path $loggingPath -ChildPath ('{0}-robocopy-{1}.log' -f $script:logFilePrefix, (Get-Date -UFormat '%Y%m%d')))

            Write-Verbose -Message ('Robocopying {0} from {1} to {2}' -f $module, $script:rcSource, $script:rcTarget) | Tee-Object -FilePath $script:logFile -Append
            Start-Process -FilePath robocopy.exe -ArgumentList ('{0} {1} /MIR /TEE /LOG+:{2} /IPG:777 /R:1 /W:1 /NP /TS /FP /DCOPY:T /DST /XD .git /XF .gitattributes /NJH' -f $script:rcSource, $script:rcTarget, $script:RCLogFile) -Wait -Verb open

            # repeat robocopy to to '2' account Modules path
            $script:rcTarget = ($script:rcTarget -replace $env:USERNAME,$($env:USERNAME+'2'))
            Write-Verbose -Message ('Robocopying {0} from {1} to {2}' -f $module, $script:rcSource, $script:rcTarget) | Tee-Object -FilePath $script:logFile -Append
            Start-Process -FilePath robocopy.exe -ArgumentList ('{0} {1} /MIR /TEE /LOG+:{1} /R:1 /W:1 /NP /TS /FP /DCOPY:T /DST /XD .git /XF .orig .gitattributes /NJH' -f $script:rcTarget, $script:RCLogFile) -Wait -Verb open

            # repeat robocopy to PowerShell-Modules repository
            Start-Process -FilePath robocopy.exe -ArgumentList ('{0} \\hcdata\apps\IT\PowerShell-Modules\{1} /MIR /TEE /LOG+:{2} /R:1 /W:1 /NP /TS /FP /DCOPY:T /DST /XD .git /XF .gitattributes /NJH' -f $script:rcSource, $module, $script:RCLogFile) -Wait -Verb open
        } else {
            Write-Warning -Message ('Failed to confirm paths; {0} OR {1}' -f $script:rcSource, $script:rcTarget)
        }
    }
    #End Region
}