#requires -Version 3
#===============================================================================
# NAME      : PowerDiff.ps1
# LANGUAGE  : Windows PowerShell
# AUTHOR    : Bryan Dady
# DATE      : 06/12/2016
# COMMENT   : PowerShell script to automate kdiff3.exe
# EXAMPLE   : PS .\> .\PowerDiff.ps1 -SourcePath .\Modules\ProfilePal -TargetPath ..\GitHub\ProfilePal -MergePath 'H:\My Documents\WindowsPowerShell\Modules\ProfilePal'
#===============================================================================
Set-StrictMode -Version latest

#Derive $logBase from script name. The most reliable automatic variable for this is $MyInvocation.MyCommand.Name
# But the value of this variable changes within Functions, so we define a shared logging base from the 'parent' script file (name) level
# all logging cmdlets later throughout this script should derive their logging path from this $logBase directory, by appending simply .log, or preferable [date].log
$logFileBase = $(Join-Path -Path "$([Environment]::GetFolderPath('MyDocuments'))" -ChildPath 'WindowsPowerShell\log')
$logFilePrefix = $($MyInvocation.MyCommand.Name.Split('.'))[0]

Write-Verbose -Message " Dot-Sourcing $($MyInvocation.MyCommand.Path)`n"

Write-Debug -Message "  ... logFileBase is $logFileBase\$logFilePrefix-[date].log"

    # Define path to local copy of kdiff3.exe
    $kdiff = Join-Path -Path $env:ProgramFiles -ChildPath 'KDiff3\kdiff3.exe' # 'TortoiseHg\kdiff3.exe'

    if ( -not (Test-Path -Path $kdiff -PathType Leaf))
    {
        $kdiff = 'R:\IT\Utilities\KDiff3\kdiff3.exe'
        if ( -not (Test-Path -Path $kdiff -PathType Leaf))
        {
            throw "Failed to find $kdiff" | Tee-Object -FilePath $logFile -Append
        }
    }
    Write-Verbose -Message "Will use diff tool: $kdiff"

    # Syntax we're going for: kdiff3 dir1 dir2 [dir3] -o destdir
    # for additional 'Help' info, browse: file:///C:/Program%20Files/KDiff3/doc/startingdirmerge.html

    # Define optional arguments / configs to pass to kdiff3.exe.
    # Config Settings (cs) defined here as an array, for easier maintenance; -joined into the $kdArgs string below, before being passed in -ArgumentList to kdiff.exe
    # For more context, run kdiff3.exe -help and/or kdiff3.exe -confighelp
    $kdiffConfig = @(
        'AutoAdvance=1',
        'AutoSaveAndQuitOnMergeWithoutConflicts=1',
        'BinaryComparison=0',
        'CreateBakFiles=1',
        'DirAntiPattern=CVS;.deps;.svn;.git',
        'EscapeKeyQuits=1',
        "FileAntiPattern=*.orig;*.o;*.ob`;.git*;*.zip;copy-module.ps1;README.md",
        'FullAnalysis=1',
        'IgnoreCase=0',
        'IgnoreComments=0',
        'IgnoreNumbers=0',
        'RecursiveDirs=1',
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

Write-Verbose -Message "Declaring Function Merge-Repository"
function Merge-Repository
{
#region Setup
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [Parameter(Mandatory = $true,Position = 0)]
        [ValidateScript({Test-Path -Path $PSItem})]
        [Alias('SourcePath','A')]
        [string]
        $file1,

        [Parameter(Mandatory = $true,Position = 1)]
        [ValidateScript({Test-Path -Path $PSItem -IsValid})]
        [Alias('TargetPath','B')]
        [string]
        $file2,

        [Parameter(Position = 2)]
        [ValidateScript({Test-Path -Path $PSItem -IsValid})]
        [Alias('MergePath','C')]
        [string]
        $file3
    )
    $error.clear()
    $erroractionpreference = 'Stop' # throw statement requires 'Stop'
    # DEBUG MODE : $erroractionpreference = "Inquire"; "`$error = $error[0]"

    # ======== BEGIN ====================

    # Build dynamic logging file path at ...\[My ]Documents\WindowsPowershell\log\[scriptname]-[rundate].log
    $logFile = $(Join-Path -Path $logFileBase -ChildPath "$logFilePrefix-$(Get-Date -UFormat '%Y%m%d').log")
    Write-Output -InputObject '' | Tee-Object -FilePath $logFile -Append
    Write-Output -InputObject "Logging to $logFile" # | Tee-Object -FilePath $logFile -Append

    $rclogFile = $(Join-Path -Path $logFileBase -ChildPath "$logFilePrefix-robocopy-$(Get-Date -UFormat '%Y%m%d').log")

    Write-Output -InputObject "$(Get-Date -Format g) # Starting $($MyInvocation.MyCommand.Name)" | Tee-Object -FilePath $logFile -Append

    $kdArgs = ' --merge --auto'+' --cs "'+$($kdiffConfig -join '" --cs "')+'"'
    Write-Debug -Message "`$kdiffConfig is set. `$kdArgs:`n$kdArgs" # | Tee-Object -FilePath $logFile -Append

    try
    {
        (Test-Path -Path $file1 | Out-Null)
    }
    catch
    {
        Write-Output -InputObject "Error was $_" | Tee-Object -FilePath $logFile -Append
        $line = $MyInvocation.ScriptLineNumber | Tee-Object -FilePath $logFile -Append
        Write-Output -InputObject "Error was in Line $line" | Tee-Object -FilePath $logFile -Append
        Write-Output -InputObject 'file1 (A) not found; nothing to merge.' | Tee-Object -FilePath $logFile -Append
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
        Write-Output -InputObject "Error was $_" | Tee-Object -FilePath $logFile -Append
        $line = $MyInvocation.ScriptLineNumber
        Write-Output -InputObject "Error was in Line $line" | Tee-Object -FilePath $logFile -Append
        Write-Output -InputObject 'file2 (B) not found; nothing to merge. Copying via Copy-Item.' | Tee-Object -FilePath $logFile -Append
        Copy-Item -Path $file1 -Destination $file2 -Recurse -Confirm | Tee-Object -FilePath $logFile -Append
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
            Write-Debug -Message "Detected MergePath : $MergePath"
            Write-Debug -Message "$kdiff $SourcePath $TargetPath $MergePath --output $MergePath $kdArgs"

            if ($PSCmdlet.ShouldProcess($SourcePath,$("Merge $SourcePath, $TargetPath, $MergePath"))) {
                Write-Debug -Message "[DEBUG] $kdiff -ArgumentList $SourcePath $TargetPath $MergePath --output $MergePath $kdArgs"
                Write-Output -InputObject "Merging $SourcePath `n: $TargetPath `n-> $MergePath" | Out-File -FilePath $logFile -Append
                Start-Process -FilePath $kdiff -ArgumentList "$SourcePath $TargetPath $MergePath --output $MergePath $kdArgs" -Wait | Tee-Object -FilePath $logFile -Append
            }

        # In a 3-way merge, kdiff3 only sync's with merged output file. So, after the merge is complete, we copy the final / merged output to the TargetPath directory.
        # Copy-Item considers double-quotes 'Illegal characters in path',  so we use the original $file2, instead of $TargetPath
        Write-Debug -Message "Copy-Item -Path $MergePath -Destination $(Split-Path -Path $file2) -Recurse -Confirm"
        # Copy-Item -Path $MergePath -Destination $(Split-Path -Path $file2) -Recurse -Confirm
            if ($PSCmdlet.ShouldProcess($MergePath,$("Copy $MergePath via Robocopy"))) {
                Write-Output -InputObject "Mirroring $MergePath back to $(Split-Path -Path $file2) (using Robocopy)" | Tee-Object -FilePath $logFile -Append
                if (Test-Path -Path $file2 -PathType Leaf | Out-Null)
                {
                    $rcTarget = $(Split-Path -Path $file2)
                }
                else
                {
                    $rcTarget = $TargetPath
                }
                Write-Debug -Message "robocopy $MergePath $rcTarget /L /MIR /TEE /MT /NP /TS /FP /DCOPY:T /DST /R:1 /W:1 /XF *.orig /NJH /NS /NC /NP /LOG+:$rclogFile"
                Write-Output -InputObject "robocopy $MergePath $rcTarget /L /MIR /TEE /MT /NP /TS /FP /DCOPY:T /DST /R:1 /W:1 /XF *.orig /NJH /NS /NC /NP /LOG+:$rclogFile" | Out-File -FilePath $logFile -Append
                & robocopy.exe $MergePath $rcTarget /L /MIR /TEE /MT /NP /TS /FP /DCOPY:T /DST /R:1 /W:1 /XF *.orig /NJH /NS /NC /NP /LOG+:$rclogFile
            }
        }
        else
        {
            Write-Debug -Message 'No MergePath; 2-way merge'
# * * * RFE : Move file-hash comparison into a function, so it can handle folder hash comparison
#            if ( -not [bool](Compare-Object -ReferenceObject (get-filehash -Path $SourcePath) (get-filehash -Path $TargetPath) -Property Hash))
#            {
                Write-Debug -Message "$kdiff $SourcePath $TargetPath $kdArgs"
                if ($PSCmdlet.ShouldProcess($SourcePath,$("Merge $SourcePath, $TargetPath"))) {
                    Write-Output -InputObject "Merging $SourcePath <-> $TargetPath" | Out-File -FilePath $logFile -Append
                    Start-Process -FilePath $kdiff -ArgumentList "$SourcePath $TargetPath $kdArgs" -Wait
                    # In a 2-way merge, with SyncMode=1 kdiff3 can sync both directories, so we can skip the copy/mirror-back activity of the 3-way merge above.
                }
#            }
#            else
#            {
#                Write-Output -InputObject "File hashes match; no action needed." | Tee-Object -FilePath $logFile -Append
#            }
        }
    #endregion

    Write-Output -InputObject "`n$(Get-Date -Format g) # Ending $($MyInvocation.MyCommand.Name)`n" | Tee-Object -FilePath $logFile -Append
    # ======== THE END ======================
    Write-Output -InputObject '' | Tee-Object -FilePath $logFile -Append
}

Write-Verbose -Message "Declaring Function Merge-MyPSFiles"
function Merge-MyPSFiles
{
[CmdletBinding(SupportsShouldProcess)]
    $logFile = $(Join-Path -Path $logFileBase -ChildPath "$logFilePrefix-$(Get-Date -UFormat '%Y%m%d').log")
    Write-Output -InputObject '' | Tee-Object -FilePath $logFile -Append
    Write-Output -InputObject "logging to $logFile"
    Write-Output -InputObject "$(Get-Date -Format g) # Starting $($MyInvocation.MyCommand.Name)" | Tee-Object -FilePath $logFile -Append

    # Third-Party PS Modules I like
    $3PModules = @( 'dbatools', 'IseHg', 'ISERegex', 'ISEScriptingGeek', 'ISESteroids', 'NetScaler', 'Patchy', 'Pester', 'PesterHelpers', 'PowerGist-ISE', 'PowershellBGInfo', 'PowerShellCookbook', 'PSScriptAnalyzer',` 
        'ScriptBrowser', 'ShowDscResource', 'SoftwareInstallManager', 'vSphereDSC', 'xActiveDirectory', 'xAdcsDeployment', 'xBitlocker', 'xCertificate', 'xChrome', 'xComputerManagement', 'xCredSSP', 'xDnsServer',`
        'xDSCResourceDesigner', 'xExchange', 'xHyper-V', 'xJea', 'xNetworking', 'xPendingReboot', 'xPowerShellExecutionPolicy', 'xPSDesiredStateConfiguration', 'xRemoteDesktopSessionHost', 'xRobocopy',`
        'xSqlPs', 'xSQLServer', 'xStorage', 'xTimeZone', 'xWebAdministration', 'xWindowsUpdate')

    <#
    Other (powershellgallery) modules to investigate
    7Zip4Powershell
    Beaver
    Carbon
    cMDT
    GlobalFunctions
    ImportExcel
    Kansa
    #>

    # My own 'custom' modules
    $MyModules = @('EditModule', 'ProfilePal', 'PSLogger', 'Sperry') # UpGuard')
    # EXAMPLE   : PS .\> .\PowerDiff.ps1 -SourcePath .\Modules\ProfilePal -TargetPath ..\GitHub\
    # Technically, per kdiff3 Help, the name of the directory-to-be-merged only needs to be specified once, when the all are the same, just at different root paths.

    $myPShome = $(Join-Path -Path "$([Environment]::GetFolderPath('MyDocuments'))" -ChildPath 'WindowsPowerShell')
    $myPShome = "\\hcdata\homes`$\gbci\$env:USERNAME\My Documents\WindowsPowerShell"
    $MyHomeModuleBase = join-path -Path $myPShome -ChildPath 'Modules'

    # *** update design to be considerate of branch bandwidth when copying from local to H:, but optimize for performance when copying in NAS
    [bool]$onServer = $false
    if ((Get-WmiObject -Class Win32_OperatingSystem -Property Caption).Caption -like '*Windows Server*')
    {
        [bool]$onServer = $true
    }

    # if 'online' at work, then we merge 3 repos, including to target H: drive
#region Merge at work
    if (Test-Path -Path $myPShome)
    {
        Write-Output -InputObject "Detected work network with 'home' drive. Merge & syncronizing to shared repository" | Tee-Object -FilePath $logFile -Append

        foreach ($module in $3PModules)
        {
            # Robocopy /MIR insted of  merge ... no need to merge 3rd party modules
            $rcTarget = """$(join-path -Path $MyHomeModuleBase -ChildPath $module)"""
            try {
                $rcSource = """$((Get-Module -Name $module -ListAvailable | Select-Object -Unique).ModuleBase)"""
                Write-Debug -Message "Updating $module (from $rcSource to $rcTarget with Robocopy)" | Tee-Object -FilePath $logFile -Append
            }
            catch {
                Write-Verbose -Message "Failed to read Module's directory property (ModuleBase)"
                break
            }

            # robocopy.exe writes wierd characters, if/when we let it share, so robocopy gets it's own log file
            $rclogFile = $(Join-Path -Path $logFileBase -ChildPath "$logFilePrefix-robocopy-$(Get-Date -UFormat '%Y%m%d').log")

            Write-Debug -Message "Updating $module (from $rcSource to $rcTarget with Robocopy)" | Tee-Object -FilePath $logFile -Append
            Start-Process -FilePath robocopy.exe -ArgumentList "$rcSource $rcTarget /MIR /TEE /LOG+:$rclogFile /IPG:777 /R:1 /W:1 /NP /TS /FP /DCOPY:T /DST /XD .git /XF .gitattributes /NJH" -Wait -Verb open
            if ($onServer) {
                # repeat robocopy to to '2' account Modules path
                $rcTarget = ($rcTarget -replace $env:USERNAME,$($env:USERNAME+'2'))
                Start-Process -FilePath robocopy.exe -ArgumentList "$rcTarget $rcTarget /MIR /TEE /LOG+:$rclogFile /R:1 /W:1 /NP /TS /FP /DCOPY:T /DST /XD .git /XF .orig .gitattributes /NJH" -Wait -Verb open

                # repeat robocopy to PowerShell-Modules repository
                Start-Process -FilePath robocopy.exe -ArgumentList "$rcSource \\hcdata\apps\IT\PowerShell-Modules\$module /MIR /TEE /LOG+:$rclogFile /R:1 /W:1 /NP /TS /FP /DCOPY:T /DST /XD .git /XF .gitattributes /NJH" -Wait -Verb open
            }
        }

        foreach ($module in $MyModules)
        {
            Write-Output -InputObject "Merging $module" | Tee-Object -FilePath $logFile -Append
            $modFullPath = join-path -Path $MyHomeModuleBase -ChildPath $module
            # first merge from 'admin' (2) workspace to primary $HOME
            Write-Verbose -Message "Merge-Repository -SourcePath $($modFullPath -replace $env:USERNAME,$($env:USERNAME+'2')) -TargetPath $modFullPath" | Tee-Object -FilePath $logFile -Append
            Merge-Repository -SourcePath "$($modFullPath -replace $env:USERNAME,$($env:USERNAME+'2'))" -TargetPath "$modFullPath" 
            # then merge network $HOME workspace with local
            Write-Verbose -Message "Merge-Repository -SourcePath $((Get-Module -Name $module -ListAvailable | Select-Object -Unique).ModuleBase) -TargetPath $modFullPath" | Tee-Object -FilePath $logFile -Append
            Merge-Repository -SourcePath "$((Get-Module -Name $module -ListAvailable | Select-Object -Unique).ModuleBase)" -TargetPath "$modFullPath"
            # -MergePath \\hcdata\apps\IT\PowerShell-Modules\$module
            # then mirror back final $HOME workspace to 'admin' (2) workspace 
            Write-Debug -Message "robocopy $modFullPath $($modFullPath -replace $env:USERNAME,$($env:USERNAME+'2')) /L /MIR /TEE /MT /NP /TS /FP /DCOPY:T /DST /R:1 /W:1 /XF *.orig /NJH /NS /NC /NP /LOG+:$rclogFile"
            Write-Output -InputObject "robocopy $modFullPath $($modFullPath -replace $env:USERNAME,$($env:USERNAME+'2')) /L /MIR /TEE /MT /NP /TS /FP /DCOPY:T /DST /R:1 /W:1 /XF *.orig /NJH /NS /NC /NP /LOG+:$rclogFile" | Out-File -FilePath $logFile -Append
            & robocopy.exe $modFullPath $($modFullPath -replace $env:USERNAME,$($env:USERNAME+'2')) /L /MIR /TEE /MT /NP /TS /FP /DCOPY:T /DST /R:1 /W:1 /XF *.orig /NJH /NS /NC /NP /LOG+:$rclogFile
        }

        if ($onServer) {
            # Merge / sync from $myPShome (share)  \scripts folder to '2' account share
            Write-Output -InputObject 'Merging $myPShome\scripts folder' | Tee-Object -FilePath $logFile -Append
            $adminHomeWPS = $myPShome -replace $env:USERNAME,$($env:USERNAME+'2')
            Merge-Repository -SourcePath "$(Join-Path -Path $myPShome -ChildPath 'Scripts')" -TargetPath "$(Join-Path -Path $adminHomeWPS -ChildPath 'Scripts')"

            # While we're at it merge any other common PS files, like profile scripts
            if (Test-Path -Path $PROFILE.CurrentUserCurrentHost)
            {
                Write-Output -InputObject 'Merging CurrentUserCurrentHost profile script' | Tee-Object -FilePath $logFile -Append
                $Profile_Script = Split-Path -Path $PROFILE.CurrentUserCurrentHost -Leaf
                Merge-Repository -SourcePath $PROFILE.CurrentUserCurrentHost -TargetPath "$myPShome\$Profile_Script" -MergePath "$adminHomeWPS\$Profile_Script"
            }

            if (Test-Path -Path $PROFILE.CurrentUserAllHosts)
            {
                Write-Output -InputObject 'Merging CurrentUserAllHosts profile script' | Tee-Object -FilePath $logFile -Append
                $Profile_Script = Split-Path -Path $PROFILE.CurrentUserCurrentHost -Leaf
                Merge-Repository -SourcePath $PROFILE.CurrentUserAllHosts -TargetPath "$myPShome\$Profile_Script" -MergePath "$adminHomeWPS\$Profile_Script"
            }

            if (Test-Path -Path $PROFILE.AllUsersCurrentHost)
            {
                Write-Output -InputObject 'Merging AllUsersCurrentHost profile script' | Tee-Object -FilePath $logFile -Append
                $Profile_Script = 'AllUsers_' + (Split-Path -Path $PROFILE.AllUsersCurrentHost -Leaf)
                Merge-Repository -SourcePath $PROFILE.AllUsersCurrentHost -TargetPath "$myPShome\$Profile_Script" -MergePath "$adminHomeWPS\$Profile_Script"
            }

            if (Test-Path -Path $PROFILE.AllUsersAllHosts)
            {
                Write-Output -InputObject 'Merging AllUsersAllHosts profile script' | Tee-Object -FilePath $logFile -Append
                $Profile_Script = 'AllUsers_' + (Split-Path -Path $PROFILE.AllUsersAllHosts -Leaf)
                Merge-Repository -SourcePath $PROFILE.AllUsersAllHosts -TargetPath "$myPShome\$Profile_Script" -MergePath "$adminHomeWPS\$Profile_Script"
            }
        }
    }
#endregion

#region Merge offline
    # otherwise, only merge repositories on local system
    if (-not $onServer) {

        Write-Output -InputObject 'Performing local (2-way) merges' | Tee-Object -FilePath $logFile -Append
        foreach ($module in $MyModules)
        {
            Write-Output -InputObject "Merging $module" | Tee-Object -FilePath $logFile -Append
            Merge-Repository -SourcePath $((Get-Module -Name $module -ListAvailable | Select-Object -Unique).ModuleBase) -TargetPath $env:USERPROFILE\Documents\GitHub\$module
        }

        # While we're at it merge any other common PS files, like profile scripts
        $ghMyScripts = Join-Path -Path $env:USERPROFILE -ChildPath 'Documents\GitHub\MyScripts'
        foreach ($psfile in @('CurrentUserCurrentHost','CurrentUserAllHosts','AllUsersCurrentHost','AllUsersAllHosts'))
        {
            if (Test-Path -Path $PROFILE.$psfile)
            {
                # Derive target path
                if ($psfile -like 'AllUsers*')
                {
                    $ScriptTargetPath = Join-Path -Path $ghMyScripts -ChildPath "AllUsers_$(Split-Path -Path $PROFILE.$psfile -Leaf)"
                }
                else
                {
                    $ScriptTargetPath = Join-Path -Path $ghMyScripts -ChildPath $(Split-Path -Path $PROFILE.$psfile -Leaf)
                }
                # Diff/Merge or copy the file
                if (Test-Path -Path $ScriptTargetPath)
                {
                    # Get file hashes and compare. If the hashes match, Compare-Object returns $false, so invert desired boolean using -not 
                    if ( -not [bool](Compare-Object -ReferenceObject (get-filehash -Path $PROFILE.$psfile) (get-filehash -Path $ScriptTargetPath) -Property Hash))
                    {
                        Write-Output -InputObject "Merging $psfile profile script" | Tee-Object -FilePath $logFile -Append
                        Merge-Repository -SourcePath $PROFILE.$psfile -TargetPath $ScriptTargetPath
                    }
                    else
                    {
                        Write-Output -InputObject "File hashes match; no action needed." | Tee-Object -FilePath $logFile -Append
                    }
                }
                else
                {
                    Write-Output -InputObject "Copying $psfile profile script" | Tee-Object -FilePath $logFile -Append
                    Copy-Item -Path $PROFILE.$psfile -Destination $ScriptTargetPath -PassThru
                }
            }
        }
    }
    #endregion

    Write-Output -InputObject "`n$(Get-Date -Format g) # Ending $($MyInvocation.MyCommand.Name)" | Tee-Object -FilePath $logFile -Append
    # ======== THE END ======================
    Write-Output -InputObject '' | Tee-Object -FilePath $logFile -Append

    # and then we open GitHub
    Set-ProcessState -ProcessName github -Action Start
}
