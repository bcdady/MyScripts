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

# Exclude these Authors (of any available PowerShell module), whcn listing available modules to copy/merge
# Referenced / used in Merge-MyPSFiles function, to distinguish 3rd party (bulk-copy) modules from locally edited / merged modules
$Author = 'Bryan Dady'
#===============================================================================
$CommandName = $MyInvocation.MyCommand.Name
$CommandPath = $MyInvocation.MyCommand.Path
$CommandType = $MyInvocation.MyCommand.CommandType
$CommandModule = $MyInvocation.MyCommand.Module
$ModuleName = $MyInvocation.MyCommand.ModuleName
$CommandParameters = $MyInvocation.MyCommand.Parameters
$ParameterSets = $MyInvocation.MyCommand.ParameterSets
$RemotingCapability = $MyInvocation.MyCommand.RemotingCapability
$Visibility = $MyInvocation.MyCommand.Visibility

if (($null -eq $CommandName) -or ($null -eq $CommandPath))
{
    # We didn't get a successful command / script name or path from $MyInvocation, so check with CallStack
    Write-Verbose -Message "Getting PSCallStack [`$CallStack = Get-PSCallStack]"
    $CallStack = Get-PSCallStack | Select-Object -First 1
    # $CallStack | Select Position, ScriptName, Command | format-list # FunctionName, ScriptLineNumber, Arguments, Location
    $ScriptName = $CallStack.ScriptName
    $Command = $CallStack.Command
    Write-Verbose -Message "`$ScriptName: $ScriptName"
    Write-Verbose -Message "`$Command: $Command"
    Write-Verbose -Message 'Assigning previously null MyCommand variables with CallStack values' -Verbose
    $CommandPath = $ScriptName
    $CommandName = $Command
}

#'Optimize New-Object invocation, based on Don Jones' recommendation: https://technet.microsoft.com/en-us/magazine/hh750381.aspx
$Private:properties = [ordered]@{
    'CommandName'        = $CommandName
    'CommandPath'        = $CommandPath
    'CommandType'        = $CommandType
    'CommandModule'      = $CommandModule
    'ModuleName'         = $ModuleName
    'CommandParameters'  = $CommandParameters.Keys
    'ParameterSets'      = $ParameterSets
    'RemotingCapability' = $RemotingCapability
    'Visibility'         = $Visibility
}
$MyScriptInfo = $Private:RetObject = New-Object -TypeName PSObject -Prop $properties
Write-Output -InputObject 'Declaring new object $MyScriptInfo'

#Derive $logBase from script name. The most reliable automatic variable for this is $MyInvocation.MyCommand.Name
# But the value of this variable changes within Functions, so we define a shared logging base from the 'parent' script file (name) level
# all logging cmdlets later throughout this script should derive their logging path from this $logBase directory, by appending simply .log, or preferable [date].log
if (-not [bool](Get-Variable -Name myPShome -Scope Global -ErrorAction Ignore))
{
    $script:myPShome = $(Join-Path -Path "$([Environment]::GetFolderPath('MyDocuments'))" -ChildPath 'WindowsPowerShell')
}

$script:logFileBase = $(Join-Path -Path $myPShome -ChildPath 'log')
$script:logFilePrefix = $($MyScriptInfo.CommandName.Split('.'))[0]

Write-Verbose -Message " Dot-Sourcing $CommandPath"

Write-Debug -Message "  ... logFileBase is $script:logFileBase\$script:logFilePrefix-[date].log"

# Define path to local copy of kdiff3.exe
$script:kdiff = Join-Path -Path $env:ProgramFiles -ChildPath 'KDiff3\kdiff3.exe' # 'TortoiseHg\kdiff3.exe'

if ( -not (Test-Path -Path $script:kdiff -PathType Leaf))
{
    $script:kdiff = 'R:\IT\Utilities\KDiff3\kdiff3.exe'
    if ( -not (Test-Path -Path $script:kdiff -PathType Leaf))
    {
        throw "Failed to find $script:kdiff" | Tee-Object -FilePath $script:logFile -Append
    }
}
Write-Verbose -Message "Will use diff tool: $script:kdiff"

# Syntax we're going for: kdiff3 dir1 dir2 [dir3] -o destdir
# for additional 'Help' info, browse: file:///C:/Program%20Files/KDiff3/doc/startingdirmerge.html

# Define optional arguments / configs to pass to kdiff3.exe.
# Config Settings (cs) defined here as an array, for easier maintenance; -joined into the $script:kdArgs string below, before being passed in -ArgumentList to kdiff.exe
# For more context, run kdiff3.exe -help and/or kdiff3.exe -confighelp
$script:kdiffConfig = @(
    'AutoAdvance=1',
    'AutoSaveAndQuitOnMergeWithoutConflicts=1',
    'BinaryComparison=0',
    'CreateBakFiles=1',
    'DirAntiPattern=CVS;.deps;.svn;.git;.hg',
    'EscapeKeyQuits=1',
    "FileAntiPattern=*.orig;*.o;*.ob`;.git*;*.zip;copy-module.ps1;README.md",
    'FullAnalysis=1',
    'IgnoreCase=0',
    'IgnoreComments=0',
    'IgnoreNumbers=0',
    'RecursiveDirs=0',
    'ReplaceTabs=1',
    'RunRegExpAutoMergeOnMergeStart=1',
    'SameEncoding=1',
    'ShowIdenticalFiles=0',
    'ShowInfoDialogs=0',
    'ShowLineNumbers=1',
    'ShowWhiteSpace=0',
    'ShowWhiteSpaceCharacters=1',
    'SyncMode=1',
    'TrustDate=0',
    'TrustDateFallbackToBinary=0',
    'TrustSize=0',
    'TryHard=1',
    'WhiteSpaceEqual=0',
    'WindowStateMaximised=1'
)
# 'SkipDirStatus=1', -- removed due to error message

$CompareDirectory = Join-Path -Path $(Split-Path -Path $CommandPath -Parent) -ChildPath 'Compare-Directory.ps1' -ErrorAction Stop
Write-Verbose -Message " Dot-Sourcing $CompareDirectory"
Write-Debug -Message " Dot-Sourcing $CompareDirectory"
. $CompareDirectory

Write-Verbose -Message "Declaring Function Merge-Repository"
function Merge-Repository
{
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [Parameter(Mandatory = $true,Position = 0)]
        [ValidateScript({Test-Path -Path $PSItem})]
        [Alias('SourcePath','A')]
        [string]
        $file1
        ,
        [Parameter(Mandatory = $true,Position = 1)]
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
    $erroractionpreference = 'Stop' # throw statement requires 'Stop'
    # DEBUG MODE : $erroractionpreference = "Inquire"; "`$error = $error[0]"

    # ======== BEGIN ====================

    # Build dynamic logging file path at ...\[My ]Documents\WindowsPowershell\log\[scriptname]-[rundate].log
    $script:logFile = $(Join-Path -Path $script:logFileBase -ChildPath "$script:logFilePrefix-$(Get-Date -UFormat '%Y%m%d').log")
    Write-Output -InputObject '' | Tee-Object -FilePath $script:logFile -Append
    Write-Verbose -Message "Logging to $script:logFile" # | Tee-Object -FilePath $script:logFile -Append

    $script:rclogFile = $(Join-Path -Path $script:logFileBase -ChildPath "$script:logFilePrefix-robocopy-$(Get-Date -UFormat '%Y%m%d').log")

    Write-Verbose -Message "$(Get-Date -Format g) # Starting Merge-Repository -file1 $file1 -file2 $file2 -file3 $file3" | Tee-Object -FilePath $script:logFile -Append

    $script:kdArgs = ' --merge --auto'+' --cs '+$($script:kdiffConfig -join ' --cs ')+''

    if ($Recurse)
    {
        $script:kdArgs = $script:kdArgs -replace 'RecursiveDirs=0','RecursiveDirs=1'
    }
<# RFE
    # enhance Parameter support to enable selective control of Recursion and File filtering
    if ($Filter)
    {
        if ($script:kdiffConfig -like "*$Filter*" -notin $PSItem.Name)
        "FileAntiPattern=*.orig;*.o;*.ob`;.git*;*.zip;copy-module.ps1;README.md",
    }
#>
    Write-Debug -Message "`$script:kdiffConfig is set. `$script:kdArgs: $script:kdArgs" | Tee-Object -FilePath $script:logFile -Append
    try
    {
        (Test-Path -Path $file1 | Out-Null)
    }
    catch
    {
        Write-Output -InputObject "Error was $_" | Tee-Object -FilePath $script:logFile -Append
        $line = $MyInvocation.ScriptLineNumber | Tee-Object -FilePath $script:logFile -Append
        Write-Output -InputObject "Error was in Line $line" | Tee-Object -FilePath $script:logFile -Append
        Write-Output -InputObject 'file1 (A) not found; nothing to merge.' | Tee-Object -FilePath $script:logFile -Append
    }

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

    #region copyfile2
    $erroractionpreference = 'stop'

    Write-Debug -Message "Test-Path -Path $file2"

    try
    {
        (Test-Path -Path $file2 | Out-Null)
    }
    catch
    {
        Write-Output -InputObject "Error was $_" | Tee-Object -FilePath $script:logFile -Append
        $line = $MyInvocation.ScriptLineNumber
        Write-Output -InputObject "Error was in Line $line" | Tee-Object -FilePath $script:logFile -Append
        Write-Output -InputObject 'file2 (B) not found; nothing to merge. Copying via Copy-Item.' | Tee-Object -FilePath $script:logFile -Append
        Copy-Item -Path $file1 -Destination $file2 -Recurse -Confirm | Tee-Object -FilePath $script:logFile -Append
    }

    #endregion

    if ($file2.Contains(' ')) {
        Write-Debug -Message "Wrapping `$TargetPath with double-quotes"
        $TargetPath = """$file2"""
    } else {
        $TargetPath = $file2
    }

    if ($file3.Contains(' ')) {
        Write-Debug -Message "Wrapping `$MergePath with double-quotes"
        $MergePath = """$file3"""
    } else {
        $MergePath = $file3
    }
#endregion

    # ======== PROCESS ==================
#region Merge
    # Show what we're going to run on the console, then actually run it.
    if ([bool]$MergePath)
    {
        Write-Verbose -Message "Detected MergePath : $MergePath"
        Write-Verbose -Message "$script:kdiff $SourcePath $TargetPath $MergePath --output $MergePath $script:kdArgs"

        if ($PSCmdlet.ShouldProcess($SourcePath,$("Merge $SourcePath, $TargetPath, $MergePath"))) {
            Write-Debug -Message "[DEBUG] $script:kdiff -ArgumentList $SourcePath $TargetPath $MergePath --output $MergePath $script:kdArgs"
            Write-Output -InputObject "Merging $SourcePath `n: $TargetPath `n-> $MergePath" | Out-File -FilePath $script:logFile -Append
            Start-Process -FilePath $script:kdiff -ArgumentList "$SourcePath $TargetPath $MergePath --output $MergePath $script:kdArgs" -Wait | Tee-Object -FilePath $script:logFile -Append
        }

        # In a 3-way merge, kdiff3 only sync's with merged output file. So, after the merge is complete, we copy the final / merged output to the TargetPath directory.
        # Copy-Item considers double-quotes 'Illegal characters in path',  so we use the original $file2, instead of $TargetPath
        Write-Verbose -Message "Copy-Item -Path $MergePath -Destination $(Split-Path -Path $file2) -Recurse -Confirm"
        # Copy-Item -Path $MergePath -Destination $(Split-Path -Path $file2) -Recurse -Confirm

        if ($PSCmdlet.ShouldProcess($MergePath,$("Copy $MergePath via Robocopy"))) {
            Write-Output -InputObject "Mirroring $MergePath back to $(Split-Path -Path $file2) (using Robocopy)" | Tee-Object -FilePath $script:logFile -Append
            if (Test-Path -Path $file2 -PathType Leaf | Out-Null)
            {
                $rcTarget = $(Split-Path -Path $file2)
            }
            else
            {
                $rcTarget = $TargetPath
            }
            Write-Verbose -Message "robocopy $MergePath $rcTarget /L /MIR /TEE /MT /NP /TS /FP /DCOPY:T /DST /R:1 /W:1 /XF *.orig /NJH /NS /NC /NP /LOG+:$script:rclogFile"
            Write-Output -InputObject "robocopy $MergePath $rcTarget /L /MIR /TEE /MT /NP /TS /FP /DCOPY:T /DST /R:1 /W:1 /XF *.orig /NJH /NS /NC /NP /LOG+:$script:rclogFile" | Out-File -FilePath $script:logFile -Append
            & robocopy.exe $MergePath $rcTarget /L /MIR /TEE /MT /NP /TS /FP /DCOPY:T /DST /R:1 /W:1 /XF *.orig /NJH /NS /NC /NP /LOG+:$script:rclogFile
        }
    }
    else
    {
        Write-Verbose -Message 'No MergePath; 2-way merge'
    # * * * RFE : Move file-hash comparison into a function, so it can handle folder hash comparison
    #            if ( -not [bool](Compare-Object -ReferenceObject (get-filehash -Path $SourcePath) (get-filehash -Path $TargetPath) -Property Hash))
    #            {
            Write-Verbose -Message "$script:kdiff $SourcePath $TargetPath $script:kdArgs"
            if ($PSCmdlet.ShouldProcess($SourcePath,$("Merge $SourcePath, $TargetPath"))) {
                Write-Output -InputObject "Merging $SourcePath <-> $TargetPath" | Out-File -FilePath $script:logFile -Append
                Start-Process -FilePath $script:kdiff -ArgumentList "$SourcePath $TargetPath $script:kdArgs" -Wait
                # In a 2-way merge, with SyncMode=1 kdiff3 can sync both directories, so we can skip the copy/mirror-back activity of the 3-way merge above.
            }
    #            }
    #            else
    #            {
    #                Write-Output -InputObject "File hashes match; no action needed." | Tee-Object -FilePath $script:logFile -Append
    #            }
    }
    #endregion

    Write-Output -InputObject "`n$(Get-Date -Format g) # Ending $($MyScriptInfo.CommandName)`n" | Tee-Object -FilePath $script:logFile -Append
    # ======== THE END ======================
    Write-Output -InputObject '' | Tee-Object -FilePath $script:logFile -Append

}

Write-Verbose -Message "Declaring Function Merge-MyPSFiles"
function Merge-MyPSFiles
{
    [CmdletBinding(SupportsShouldProcess)]
    param ()

    # Specifying the logFile name now explicitly updates the datestamp on the log file
    $script:logFile = $(Join-Path -Path $script:logFileBase -ChildPath "$script:logFilePrefix-$(Get-Date -UFormat '%Y%m%d').log")
    Write-Output -InputObject '' | Tee-Object -FilePath $script:logFile -Append
    Write-Output -InputObject "logging to $script:logFile"
    Write-Output -InputObject "$(Get-Date -Format g) # Starting Merge-MyPSFiles" | Tee-Object -FilePath $script:logFile -Append

    # EXAMPLE   : PS .\> .\PowerDiff.ps1 -SourcePath .\Modules\ProfilePal -TargetPath ..\GitHub\
    # Technically, per kdiff3 Help, the name of the directory-to-be-merged only needs to be specified once, when the all are the same, just at different root paths.

    $3PModules = Get-Module -ListAvailable -Refresh | Where-Object -FilterScript {($PSItem.Author -ne "$Author") -and ($PSItem.Path -notlike "*system32*")} | Select-Object -Property Name,Author

    # My own 'custom' modules
    $MyModules = Get-Module -ListAvailable -Refresh | Where-Object -FilterScript {($PSItem.Author -eq "$Author")} # @('EditModule', 'ProfilePal', 'PSLogger', 'Sperry') # UpGuard')

    # *** update design to be considerate of branch bandwidth when copying from local to H:, but optimize for performance when copying in NAS
    if (-not [bool](Get-Variable -Name onServer -Scope Global -ErrorAction Ignore))
    {
        [bool]$onServer = $false
        if ((Get-WmiObject -Class Win32_OperatingSystem -Property Caption).Caption -like '*Windows Server*')
        {
            [bool]$Global:onServer = $true
        }
    }

    # if 'online' at work, then we merge 3 repos, including to target H: drive
#region Merge at work
    if ($Global:onServer)
    {
        Write-Output -InputObject "Detected running on server OS. Merge & syncronizing to shared repository(ies)." | Tee-Object -FilePath $script:logFile -Append
        
        # Declare root path of where modules should be merged To
        $myModulesRoot = join-path -Path $myPShome -ChildPath 'Modules'

        foreach ($module in $script:3PModules)
        {
            # Robocopy /MIR insted of  merge ... no need to merge 3rd party modules
            $script:rcTarget = """$(join-path -Path $myModulesRoot -ChildPath $module)"""
            try
            {
                $script:rcSource = """$((Get-Module -Name $module -ListAvailable | Select-Object -Unique).ModuleBase)"""
                Write-Verbose -Message "Updating $module (from $script:rcSource to $script:rcTarget with Robocopy)" | Tee-Object -FilePath $script:logFile -Append
            }
            catch
            {
                Write-Verbose -Message "Failed to read Module's directory property (ModuleBase)"
                break
            }

            # robocopy.exe writes wierd characters, if/when we let it share, so robocopy gets it's own log file
            $script:rclogFile = $(Join-Path -Path $script:logFileBase -ChildPath "$script:logFilePrefix-robocopy-$(Get-Date -UFormat '%Y%m%d').log")

            Write-Verbose -Message "Robocopying $module from $script:rcSource to $script:rcTarget" | Tee-Object -FilePath $script:logFile -Append
            Start-Process -FilePath robocopy.exe -ArgumentList "$script:rcSource $script:rcTarget /MIR /TEE /LOG+:$script:rclogFile /IPG:777 /R:1 /W:1 /NP /TS /FP /DCOPY:T /DST /XD .git /XF .gitattributes /NJH" -Wait -Verb open

            # repeat robocopy to to '2' account Modules path
            $script:rcTarget = ($script:rcTarget -replace $env:USERNAME,$($env:USERNAME+'2'))
            Write-Verbose -Message "Robocopying $module from $script:rcSource to $script:rcTarget" | Tee-Object -FilePath $script:logFile -Append
            Start-Process -FilePath robocopy.exe -ArgumentList "$script:rcTarget $script:rcTarget /MIR /TEE /LOG+:$script:rclogFile /R:1 /W:1 /NP /TS /FP /DCOPY:T /DST /XD .git /XF .orig .gitattributes /NJH" -Wait -Verb open

            # repeat robocopy to PowerShell-Modules repository
            Start-Process -FilePath robocopy.exe -ArgumentList "$script:rcSource \\hcdata\apps\IT\PowerShell-Modules\$module /MIR /TEE /LOG+:$script:rclogFile /R:1 /W:1 /NP /TS /FP /DCOPY:T /DST /XD .git /XF .gitattributes /NJH" -Wait -Verb open
        }

        # Declare / define admin '2' account home share path
        $private:2PShome = $script:myPShome -replace '^H\:','I:'

        foreach ($module in $MyModules)
        {
            Write-Output -InputObject "Merging $module (onServer)" | Tee-Object -FilePath $script:logFile -Append
            $script:modFullPath = join-path -Path $myModulesRoot -ChildPath $module

            # Compare Directories (via contained file hashes) before sending to Merge-Repository
            Write-Verbose -Message "[bool](Compare-Directory -ReferenceDirectory $script:modFullPath -DifferenceDirectory $($script:modFullPath -replace $script:myPShome,$private:2PShome) -ExcludeFile ""*.orig"","".git*"",""*.md"",""*.tests.*"")"
            Write-Verbose -Message "$([bool](Compare-Directory -ReferenceDirectory $script:modFullPath -DifferenceDirectory $($script:modFullPath -replace $script:myPShome,$private:2PShome) -ExcludeFile ""*.orig"","".git*"",""*.md"",""*.tests.*""))"
            if (Compare-Directory -ReferenceDirectory $script:modFullPath -DifferenceDirectory $($script:modFullPath -replace $script:myPShome,$private:2PShome) -ExcludeFile "*.orig",".git*","*.md","*.tests.*")
            {
                Write-Verbose -Message "No differences detected between repositories. Skipping merge."
            }
            else
            {
                Write-Verbose -Message "Compare-Directory function indicates differences detected between repositories. Proceeding with Merge-Repository."
                # first merge from 'admin' (2) workspace to primary $HOME
                Write-Verbose -Message "Merge-Repository -SourcePath $($script:modFullPath -replace $script:myPShome,$private:2PShome) -TargetPath $script:modFullPath" | Tee-Object -FilePath $script:logFile -Append
                Merge-Repository -SourcePath "$($script:modFullPath -replace $script:myPShome,$private:2PShome)" -TargetPath "$script:modFullPath" 

                # then merge network $HOME workspace with local
                Write-Verbose -Message "Merge-Repository -SourcePath $((Get-Module -Name $module -ListAvailable | Select-Object -Unique).ModuleBase) -TargetPath $script:modFullPath" | Tee-Object -FilePath $script:logFile -Append
                Merge-Repository -SourcePath "$((Get-Module -Name $module -ListAvailable | Select-Object -Unique).ModuleBase)" -TargetPath "$script:modFullPath"

                # then mirror back final $HOME workspace to 'admin' (2) workspace 
                Write-Verbose -Message "robocopy $script:modFullPath $($script:modFullPath -replace $script:myPShome,$private:2PShome) /L /MIR /TEE /MT /NP /TS /FP /DCOPY:T /DST /R:1 /W:1 /XF *.orig /NJH /NS /NC /NP /LOG+:$script:rclogFile" | Out-File -FilePath $script:logFile -Append
                Start-Process -FilePath robocopy.exe -ArgumentList "$script:modFullPath $($script:modFullPath -replace $script:myPShome,$private:2PShome) /L /MIR /TEE /MT /NP /TS /FP /DCOPY:T /DST /R:1 /W:1 /XF *.orig /NJH /NS /NC /NP /LOG+:$script:rclogFile" -Wait -Verb open
            } # end if Compare-Directory
        }

        # Compare Directories (via contained file hashes) before sending to Merge-Repository
        Write-Verbose -Message "[bool](Compare-Directory -ReferenceDirectory $(Join-Path -Path $script:myPShome -ChildPath 'Scripts') -DifferenceDirectory $(Join-Path -Path $private:2PShome -ChildPath 'Scripts') -ExcludeFile ""*.orig"","".git*"",""*.md"",""*.tests.*"" -IncludeEqual)"
        Write-Verbose -Message "$([bool](Compare-Directory -ReferenceDirectory $(Join-Path -Path $script:myPShome -ChildPath 'Scripts') -DifferenceDirectory $(Join-Path -Path $private:2PShome -ChildPath 'Scripts') -ExcludeFile ""*.orig"","".git*"",""*.md"",""*.tests.*"" -IncludeEqual))"
        if (Compare-Directory -ReferenceDirectory $(Join-Path -Path $script:myPShome -ChildPath 'Scripts') -DifferenceDirectory $(Join-Path -Path $private:2PShome -ChildPath 'Scripts') -ExcludeFile "*.orig",".git*","*.md","*.tests.*")
        {
            Write-Verbose -Message "No differences detected between repositories. Skipping merge."
        }
        else
        {
            Write-Verbose -Message "Compare-Directory function indicates differences detected between repositories. Proceeding with Merge-Repository."
            # Merge / sync from $script:myPShome (share)  \scripts folder to '2' account share; presumably mapped to I: drive root e.g. by Sperry module
            Write-Output -InputObject 'Merging $script:myPShome\scripts folder' | Tee-Object -FilePath $script:logFile -Append
    #        $script:adminHomeWPS = $script:myPShome -replace $env:USERNAME,$($env:USERNAME+'2')
            Merge-Repository -SourcePath "$(Join-Path -Path $script:myPShome -ChildPath 'Scripts')" -TargetPath "$(Join-Path -Path $private:2PShome -ChildPath 'Scripts')"

            # Merge / sync from PowerShell (console) Profile script
            $script:ScriptSourcePath = Resolve-Path -Path $(($PROFILE | Get-ChildItem).FullName)
            $script:ScriptTargetPath = Join-Path -Path $private:2PShome -ChildPath $(($PROFILE | Get-ChildItem).Name)

            # Diff/Merge or copy the file
            if (Test-Path -Path $script:ScriptTargetPath -ErrorAction Stop)
            {
                Write-Verbose -Message "Copying profile script to $private:2PShome" | Tee-Object -FilePath $script:logFile -Append
                # Get file hashes and compare. If the hashes match, Compare-Object returns $false, so invert desired boolean using -not 
                if ( -not [bool](Compare-Object -ReferenceObject $(get-filehash -Path $script:ScriptSourcePath).Hash -DifferenceObject $(get-filehash -Path $script:ScriptTargetPath).Hash -IncludeEqual))
                {
                    Write-Verbose -Message "Copying profile script $script:ScriptSourcePath" | Tee-Object -FilePath $script:logFile -Append
                    Merge-Repository -SourcePath $script:ScriptSourcePath -TargetPath $script:ScriptTargetPath
                }
                else
                {
                    Write-Output -InputObject "File hashes match; no action needed." | Tee-Object -FilePath $script:logFile -Append
                }
            } # end if Test-Path

        } # end if Compare-Directory
    } # end if onServer
#endregion

#region Merge offline
    # otherwise, only merge repositories on local system
    if (-not $Global:onServer)
    {
        Write-Output -InputObject 'Performing local (2-way) merges' | Tee-Object -FilePath $script:logFile -Append
        # Derive target path root from (Global) $myPShome, of which the -Parent dir should be [My ]Documents
        foreach ($module in $MyModules)
        {
            Write-Output -InputObject "Merging $module (locally)" | Tee-Object -FilePath $script:logFile -Append
            Merge-Repository -SourcePath $((Get-Module -Name $module -ListAvailable | Select-Object -Unique).ModuleBase) -TargetPath $env:USERPROFILE\Documents\GitHub\$module
        }

        # Merge PowerShell\Scripts folder with ..\GitHub\MyScripts local repo
        # $script:ghMyScripts = Join-Path -Path $(Split-Path -Path $myPShome -Parent) -ChildPath 'GitHub\MyScripts'
        $script:PSScripts = Join-Path -Path $myPShome -ChildPath 'Scripts'
        Merge-Repository -SourcePath $script:PSScripts -TargetPath "$(Join-Path -Path $(Split-Path -Path $myPShome -Parent) -ChildPath 'GitHub\MyScripts')"

        if (Test-Path -Path 'H:\My Documents\WindowsPowerShell' -ErrorAction SilentlyContinue)
        {

            Write-Output -InputObject 'Performing $HOME (2-way) merges' | Tee-Object -FilePath $script:logFile -Append
            # Derive target path root from (Global) $myPShome, of which the -Parent dir should be [My ]Documents
            foreach ($module in $MyModules)
            {
                Write-Output -InputObject "Merging $module (locally)" | Tee-Object -FilePath $script:logFile -Append
                Merge-Repository -SourcePath $((Get-Module -Name $module -ListAvailable | Select-Object -Unique).ModuleBase) -TargetPath (Join-Path -Path 'H:\My Documents\WindowsPowerShell' -ChildPath 'Modules')
            }

            # Merge local PowerShell\Scripts folder with $HOME\PowerShell\Scripts folder
            # $script:ghMyScripts = Join-Path -Path $(Split-Path -Path $myPShome -Parent) -ChildPath 'GitHub\MyScripts'
            Merge-Repository -SourcePath $script:PSScripts -TargetPath 'H:\My Documents\WindowsPowerShell\Scripts'
        }
        
        # While we're at it merge primary profile script
        if (Test-Path -Path $PROFILE)
        {
            $script:ScriptSourcePath = Resolve-Path -Path $(($PROFILE | Get-ChildItem).FullName)
            $script:ScriptTargetPath = Join-Path -Path $script:ghMyScripts -ChildPath $(($PROFILE | Get-ChildItem).Name)

            # Diff/Merge or copy the file
            if (Test-Path -Path $script:ScriptTargetPath -ErrorAction Stop)
            {
                Write-Verbose -Message "Copying profile script to $script:ghMyScripts" | Tee-Object -FilePath $script:logFile -Append
                # Get file hashes and compare. If the hashes match, Compare-Object returns $false, so invert desired boolean using -not 
                if ( -not [bool](Compare-Object -ReferenceObject (get-filehash -Path $script:ScriptSourcePath) (get-filehash -Path $script:ScriptTargetPath) -Property Hash))
                {
                    Write-Verbose -Message "Copying profile script $script:ScriptSourcePath" | Tee-Object -FilePath $script:logFile -Append
                    Merge-Repository -SourcePath $script:ScriptSourcePath -TargetPath $script:ScriptTargetPath
                }
                else
                {
                    Write-Output -InputObject "File hashes match; no action needed." | Tee-Object -FilePath $script:logFile -Append
                }
            }

            $script:ScriptTargetPath = Join-Path -Path $script:ghMyScripts -ChildPath $(($PROFILE | Get-ChildItem).Name)

            # Diff/Merge or copy the file
            if (Test-Path -Path $script:ScriptTargetPath -ErrorAction Stop)
            {
                Write-Verbose -Message "Copying profile script to $script:ghMyScripts" | Tee-Object -FilePath $script:logFile -Append
                # Get file hashes and compare. If the hashes match, Compare-Object returns $false, so invert desired boolean using -not 
                if ( -not [bool](Compare-Object -ReferenceObject (get-filehash -Path $script:ScriptSourcePath) (get-filehash -Path $script:ScriptTargetPath) -Property Hash))
                {
                    Write-Verbose -Message "Copying profile script $script:ScriptSourcePath" | Tee-Object -FilePath $script:logFile -Append
                    Merge-Repository -SourcePath $script:ScriptSourcePath -TargetPath $script:ScriptTargetPath
                }
                else
                {
                    Write-Output -InputObject "File hashes match; no action needed." | Tee-Object -FilePath $script:logFile -Append
                }
            }

        } # end if test-path
    } # end if NOT onServer
    #endregion

    Write-Output -InputObject "`n$(Get-Date -Format g) # Ending $($MyScriptInfo.CommandName)" | Tee-Object -FilePath $script:logFile -Append
    # ======== THE END ======================
    Write-Output -InputObject '' | Tee-Object -FilePath $script:logFile -Append

    # and then open GitHub desktop
    Set-ProcessState -ProcessName github -Action Start -Verbose
} # end of function
