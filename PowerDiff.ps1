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
[CmdletBinding(SupportsShouldProcess)]

#Derive $logBase from script name. The most reliable automatic variable for this is $MyInvocation.MyCommand.Name
# But the value of this variable changes within Functions, so we define a shared logging base from the 'parent' script file (name) level
# all logging cmdlets later throughout this script should derive their logging path from this $logBase directory, by appending simply .log, or preferable [date].log
$script:logFileBase = $(Join-Path -Path "$([Environment]::GetFolderPath('MyDocuments'))" -ChildPath 'WindowsPowerShell\log')
$script:logFilePrefix = $($MyInvocation.MyCommand.Name.Split('.'))[0]

Write-Verbose -Message " Dot-Sourcing $($MyInvocation.MyCommand.Path)`n"

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
    )
    $error.clear()
    $erroractionpreference = 'Stop' # throw statement requires 'Stop'
    # DEBUG MODE : $erroractionpreference = "Inquire"; "`$error = $error[0]"

    # ======== BEGIN ====================

    # Build dynamic logging file path at ...\[My ]Documents\WindowsPowershell\log\[scriptname]-[rundate].log
    $script:logFile = $(Join-Path -Path $script:logFileBase -ChildPath "$script:logFilePrefix-$(Get-Date -UFormat '%Y%m%d').log")
    Write-Output -InputObject '' | Tee-Object -FilePath $script:logFile -Append
    Write-Output -InputObject "Logging to $script:logFile" # | Tee-Object -FilePath $script:logFile -Append

    $script:rclogFile = $(Join-Path -Path $script:logFileBase -ChildPath "$script:logFilePrefix-robocopy-$(Get-Date -UFormat '%Y%m%d').log")

    Write-Output -InputObject "$(Get-Date -Format g) # Starting $($MyInvocation.MyCommand.Name)" | Tee-Object -FilePath $script:logFile -Append

    $script:kdArgs = ' --merge --auto'+' --cs "'+$($script:kdiffConfig -join '" --cs "')+'"'
    Write-Debug -Message "`$script:kdiffConfig is set. `$script:kdArgs:`n$script:kdArgs" # | Tee-Object -FilePath $script:logFile -Append

    try
    {
        (Test-Path -Path $file1 | Out-Null)
    }
    catch
    {
        Write-Output -InputObject "Error was $_" | Tee-Object -FilePath $script:logFile -Append
        $script:line = $MyInvocation.ScriptLineNumber | Tee-Object -FilePath $script:logFile -Append
        Write-Output -InputObject "Error was in Line $script:line" | Tee-Object -FilePath $script:logFile -Append
        Write-Output -InputObject 'file1 (A) not found; nothing to merge.' | Tee-Object -FilePath $script:logFile -Append
    }

    # To handle spaces in paths, for kdiff3, without triggering ValidateScript errors against the functions defined parameters, we copy the function paramters to internal variables
    # kdiff file1 / 'A' = $script:SourcePath
    # kdiff file2 / 'B' = $script:TargetPath
    # kdiff file3 / 'C' = $script:MergePath
    if ($file1.Contains(' ')) {
        Write-Debug -Message "Wrapping `$script:SourcePath with double-quotes"
        $script:SourcePath = """$file1"""
    } else {
        $script:SourcePath = $file1
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
        $script:line = $MyInvocation.ScriptLineNumber
        Write-Output -InputObject "Error was in Line $script:line" | Tee-Object -FilePath $script:logFile -Append
        Write-Output -InputObject 'file2 (B) not found; nothing to merge. Copying via Copy-Item.' | Tee-Object -FilePath $script:logFile -Append
        Copy-Item -Path $file1 -Destination $file2 -Recurse -Confirm | Tee-Object -FilePath $script:logFile -Append
    }

    #endregion

    if ($file2.Contains(' ')) {
        Write-Debug -Message "Wrapping `$script:TargetPath with double-quotes"
        $script:TargetPath = """$file2"""
    } else {
        $script:TargetPath = $file2
    }

    if ($file3.Contains(' ')) {
        Write-Debug -Message "Wrapping `$script:MergePath with double-quotes"
        $script:MergePath = """$file3"""
    } else {
        $script:MergePath = $file3
    }
#endregion

    # ======== PROCESS ==================
#region Merge
        # Show what we're going to run on the console, then actually run it.
        if ([bool]$script:MergePath)
        {
            Write-Debug -Message "Detected MergePath : $script:MergePath"
            Write-Debug -Message "$script:kdiff $script:SourcePath $script:TargetPath $script:MergePath --output $script:MergePath $script:kdArgs"

            if ($PSCmdlet.ShouldProcess($script:SourcePath,$("Merge $script:SourcePath, $script:TargetPath, $script:MergePath"))) {
                Write-Debug -Message "[DEBUG] $script:kdiff -ArgumentList $script:SourcePath $script:TargetPath $script:MergePath --output $script:MergePath $script:kdArgs"
                Write-Output -InputObject "Merging $script:SourcePath `n: $script:TargetPath `n-> $script:MergePath" | Out-File -FilePath $script:logFile -Append
                Start-Process -FilePath $script:kdiff -ArgumentList "$script:SourcePath $script:TargetPath $script:MergePath --output $script:MergePath $script:kdArgs" -Wait | Tee-Object -FilePath $script:logFile -Append
            }

        # In a 3-way merge, kdiff3 only sync's with merged output file. So, after the merge is complete, we copy the final / merged output to the TargetPath directory.
        # Copy-Item considers double-quotes 'Illegal characters in path',  so we use the original $file2, instead of $script:TargetPath
        Write-Debug -Message "Copy-Item -Path $script:MergePath -Destination $(Split-Path -Path $file2) -Recurse -Confirm"
        # Copy-Item -Path $script:MergePath -Destination $(Split-Path -Path $file2) -Recurse -Confirm
            if ($PSCmdlet.ShouldProcess($script:MergePath,$("Copy $script:MergePath via Robocopy"))) {
                Write-Output -InputObject "Mirroring $script:MergePath back to $(Split-Path -Path $file2) (using Robocopy)" | Tee-Object -FilePath $script:logFile -Append
                if (Test-Path -Path $file2 -PathType Leaf | Out-Null)
                {
                    $script:rcTarget = $(Split-Path -Path $file2)
                }
                else
                {
                    $script:rcTarget = $script:TargetPath
                }
                Write-Debug -Message "robocopy $script:MergePath $script:rcTarget /L /MIR /TEE /MT /NP /TS /FP /DCOPY:T /DST /R:1 /W:1 /XF *.orig /NJH /NS /NC /NP /LOG+:$script:rclogFile"
                Write-Output -InputObject "robocopy $script:MergePath $script:rcTarget /L /MIR /TEE /MT /NP /TS /FP /DCOPY:T /DST /R:1 /W:1 /XF *.orig /NJH /NS /NC /NP /LOG+:$script:rclogFile" | Out-File -FilePath $script:logFile -Append
                & robocopy.exe $script:MergePath $script:rcTarget /L /MIR /TEE /MT /NP /TS /FP /DCOPY:T /DST /R:1 /W:1 /XF *.orig /NJH /NS /NC /NP /LOG+:$script:rclogFile
            }
        }
        else
        {
            Write-Debug -Message 'No MergePath; 2-way merge'
# * * * RFE : Move file-hash comparison into a function, so it can handle folder hash comparison
#            if ( -not [bool](Compare-Object -ReferenceObject (get-filehash -Path $script:SourcePath) (get-filehash -Path $script:TargetPath) -Property Hash))
#            {
                Write-Debug -Message "$script:kdiff $script:SourcePath $script:TargetPath $script:kdArgs"
                if ($PSCmdlet.ShouldProcess($script:SourcePath,$("Merge $script:SourcePath, $script:TargetPath"))) {
                    Write-Output -InputObject "Merging $script:SourcePath <-> $script:TargetPath" | Out-File -FilePath $script:logFile -Append
                    Start-Process -FilePath $script:kdiff -ArgumentList "$script:SourcePath $script:TargetPath $script:kdArgs" -Wait
                    # In a 2-way merge, with SyncMode=1 kdiff3 can sync both directories, so we can skip the copy/mirror-back activity of the 3-way merge above.
                }
#            }
#            else
#            {
#                Write-Output -InputObject "File hashes match; no action needed." | Tee-Object -FilePath $script:logFile -Append
#            }
        }
    #endregion

    Write-Output -InputObject "`n$(Get-Date -Format g) # Ending $($MyInvocation.MyCommand.Name)`n" | Tee-Object -FilePath $script:logFile -Append
    # ======== THE END ======================
    Write-Output -InputObject '' | Tee-Object -FilePath $script:logFile -Append
}

Write-Verbose -Message "Declaring Function Merge-MyPSFiles"
function Merge-MyPSFiles
{
[CmdletBinding(SupportsShouldProcess)]
    $script:logFile = $(Join-Path -Path $script:logFileBase -ChildPath "$script:logFilePrefix-$(Get-Date -UFormat '%Y%m%d').log")
    Write-Output -InputObject '' | Tee-Object -FilePath $script:logFile -Append
    Write-Output -InputObject "logging to $script:logFile"
    Write-Output -InputObject "$(Get-Date -Format g) # Starting $($MyInvocation.MyCommand.Name)" | Tee-Object -FilePath $script:logFile -Append

    # Third-Party PS Modules I like
    $script:3PModules = @( 'Carbon', 'dbatools', 'IseHg', 'ISERegex', 'ISEScriptingGeek', 'ISESteroids', 'NetScaler', 'Patchy', 'Pester', 'PesterHelpers', 'PowerGist-ISE', 'PowershellBGInfo', 'PowerShellCookbook', 'PSScriptAnalyzer',` 
        'ScriptBrowser', 'ShowDscResource', 'SoftwareInstallManager', 'vSphereDSC', 'xActiveDirectory', 'xAdcsDeployment', 'xBitlocker', 'xCertificate', 'xChrome', 'xComputerManagement', 'xCredSSP', 'xDnsServer',`
        'xDSCResourceDesigner', 'xExchange', 'xHyper-V', 'xJea', 'xNetworking', 'xPendingReboot', 'xPowerShellExecutionPolicy', 'xPSDesiredStateConfiguration', 'xRemoteDesktopSessionHost', 'xRobocopy',`
        'xSqlPs', 'xSQLServer', 'xStorage', 'xTimeZone', 'xWebAdministration', 'xWindowsUpdate')

    <#
    Other (powershellgallery) modules to investigate
    7Zip4Powershell
    Beaver
    cMDT
    GlobalFunctions
    ImportExcel
    Kansa
    #>

    # My own 'custom' modules
    $script:MyModules = @('EditModule', 'ProfilePal', 'PSLogger', 'Sperry') # UpGuard')
    # EXAMPLE   : PS .\> .\PowerDiff.ps1 -SourcePath .\Modules\ProfilePal -TargetPath ..\GitHub\
    # Technically, per kdiff3 Help, the name of the directory-to-be-merged only needs to be specified once, when the all are the same, just at different root paths.

    $script:myPShome = $(Join-Path -Path "$([Environment]::GetFolderPath('MyDocuments'))" -ChildPath 'WindowsPowerShell')
    $script:myPShome = "\\hcdata\homes`$\gbci\$env:USERNAME\My Documents\WindowsPowerShell"
    $script:myModuleBase = join-path -Path $script:myPShome -ChildPath 'Modules'

    # *** update design to be considerate of branch bandwidth when copying from local to H:, but optimize for performance when copying in NAS
    [bool]$script:onServer = $false
    if ((Get-WmiObject -Class Win32_OperatingSystem -Property Caption).Caption -like '*Windows Server*')
    {
        [bool]$script:onServer = $true
    }

    # if 'online' at work, then we merge 3 repos, including to target H: drive
#region Merge at work
    if (Test-Path -Path $script:myPShome)
    {
        Write-Output -InputObject "Detected work network with 'home' drive. Merge & syncronizing to shared repository" | Tee-Object -FilePath $script:logFile -Append

        foreach ($module in $script:3PModules)
        {
            # Robocopy /MIR insted of  merge ... no need to merge 3rd party modules
            $script:rcTarget = """$(join-path -Path $script:myModuleBase -ChildPath $module)"""
            try {
                $rcSource = """$((Get-Module -Name $module -ListAvailable | Select-Object -Unique).ModuleBase)"""
                Write-Debug -Message "Updating $module (from $rcSource to $script:rcTarget with Robocopy)" | Tee-Object -FilePath $script:logFile -Append
            }
            catch {
                Write-Verbose -Message "Failed to read Module's directory property (ModuleBase)"
                break
            }

            # robocopy.exe writes wierd characters, if/when we let it share, so robocopy gets it's own log file
            $script:rclogFile = $(Join-Path -Path $script:logFileBase -ChildPath "$script:logFilePrefix-robocopy-$(Get-Date -UFormat '%Y%m%d').log")

            Write-Debug -Message "Updating $module (from $rcSource to $script:rcTarget with Robocopy)" | Tee-Object -FilePath $script:logFile -Append
            Start-Process -FilePath robocopy.exe -ArgumentList "$rcSource $script:rcTarget /MIR /TEE /LOG+:$script:rclogFile /IPG:777 /R:1 /W:1 /NP /TS /FP /DCOPY:T /DST /XD .git /XF .gitattributes /NJH" -Wait -Verb open
            if ($script:onServer) {
                # repeat robocopy to to '2' account Modules path
                $script:rcTarget = ($script:rcTarget -replace $env:USERNAME,$($env:USERNAME+'2'))
                Start-Process -FilePath robocopy.exe -ArgumentList "$script:rcTarget $script:rcTarget /MIR /TEE /LOG+:$script:rclogFile /R:1 /W:1 /NP /TS /FP /DCOPY:T /DST /XD .git /XF .orig .gitattributes /NJH" -Wait -Verb open

                # repeat robocopy to PowerShell-Modules repository
                Start-Process -FilePath robocopy.exe -ArgumentList "$rcSource \\hcdata\apps\IT\PowerShell-Modules\$module /MIR /TEE /LOG+:$script:rclogFile /R:1 /W:1 /NP /TS /FP /DCOPY:T /DST /XD .git /XF .gitattributes /NJH" -Wait -Verb open
            }
        }

        foreach ($module in $script:MyModules)
        {
            Write-Output -InputObject "Merging $module" | Tee-Object -FilePath $script:logFile -Append
            $script:modFullPath = join-path -Path $script:myModuleBase -ChildPath $module
            # first merge from 'admin' (2) workspace to primary $HOME
            Write-Verbose -Message "Merge-Repository -SourcePath $($script:modFullPath -replace $env:USERNAME,$($env:USERNAME+'2')) -TargetPath $script:modFullPath" | Tee-Object -FilePath $script:logFile -Append
            Merge-Repository -SourcePath "$($script:modFullPath -replace $env:USERNAME,$($env:USERNAME+'2'))" -TargetPath "$script:modFullPath" 
            # then merge network $HOME workspace with local
            Write-Verbose -Message "Merge-Repository -SourcePath $((Get-Module -Name $module -ListAvailable | Select-Object -Unique).ModuleBase) -TargetPath $script:modFullPath" | Tee-Object -FilePath $script:logFile -Append
            Merge-Repository -SourcePath "$((Get-Module -Name $module -ListAvailable | Select-Object -Unique).ModuleBase)" -TargetPath "$script:modFullPath"
            # -MergePath \\hcdata\apps\IT\PowerShell-Modules\$module
            # then mirror back final $HOME workspace to 'admin' (2) workspace 
            Write-Debug -Message "robocopy $script:modFullPath $($script:modFullPath -replace $env:USERNAME,$($env:USERNAME+'2')) /L /MIR /TEE /MT /NP /TS /FP /DCOPY:T /DST /R:1 /W:1 /XF *.orig /NJH /NS /NC /NP /LOG+:$script:rclogFile"
            Write-Output -InputObject "robocopy $script:modFullPath $($script:modFullPath -replace $env:USERNAME,$($env:USERNAME+'2')) /L /MIR /TEE /MT /NP /TS /FP /DCOPY:T /DST /R:1 /W:1 /XF *.orig /NJH /NS /NC /NP /LOG+:$script:rclogFile" | Out-File -FilePath $script:logFile -Append
            & robocopy.exe $script:modFullPath $($script:modFullPath -replace $env:USERNAME,$($env:USERNAME+'2')) /L /MIR /TEE /MT /NP /TS /FP /DCOPY:T /DST /R:1 /W:1 /XF *.orig /NJH /NS /NC /NP /LOG+:$script:rclogFile
        }

        if ($script:onServer) {
            # Merge / sync from $script:myPShome (share)  \scripts folder to '2' account share
            Write-Output -InputObject 'Merging $script:myPShome\scripts folder' | Tee-Object -FilePath $script:logFile -Append
            $script:adminHomeWPS = $script:myPShome -replace $env:USERNAME,$($env:USERNAME+'2')
            Merge-Repository -SourcePath "$(Join-Path -Path $script:myPShome -ChildPath 'Scripts')" -TargetPath "$(Join-Path -Path $script:adminHomeWPS -ChildPath 'Scripts')"

            # While we're at it merge any other common PS files, like profile scripts
            if (Test-Path -Path $PROFILE.CurrentUserCurrentHost)
            {
                Write-Output -InputObject 'Merging CurrentUserCurrentHost profile script' | Tee-Object -FilePath $script:logFile -Append
                $script:Profile_Script = Split-Path -Path $PROFILE.CurrentUserCurrentHost -Leaf
                Merge-Repository -SourcePath $PROFILE.CurrentUserCurrentHost -TargetPath "$script:myPShome\$script:Profile_Script" -MergePath "$script:adminHomeWPS\$script:Profile_Script"
            }

            if (Test-Path -Path $PROFILE.CurrentUserAllHosts)
            {
                Write-Output -InputObject 'Merging CurrentUserAllHosts profile script' | Tee-Object -FilePath $script:logFile -Append
                $script:Profile_Script = Split-Path -Path $PROFILE.CurrentUserCurrentHost -Leaf
                Merge-Repository -SourcePath $PROFILE.CurrentUserAllHosts -TargetPath "$script:myPShome\$script:Profile_Script" -MergePath "$script:adminHomeWPS\$script:Profile_Script"
            }

            if (Test-Path -Path $PROFILE.AllUsersCurrentHost)
            {
                Write-Output -InputObject 'Merging AllUsersCurrentHost profile script' | Tee-Object -FilePath $script:logFile -Append
                $script:Profile_Script = 'AllUsers_' + (Split-Path -Path $PROFILE.AllUsersCurrentHost -Leaf)
                Merge-Repository -SourcePath $PROFILE.AllUsersCurrentHost -TargetPath "$script:myPShome\$script:Profile_Script" -MergePath "$script:adminHomeWPS\$script:Profile_Script"
            }

            if (Test-Path -Path $PROFILE.AllUsersAllHosts)
            {
                Write-Output -InputObject 'Merging AllUsersAllHosts profile script' | Tee-Object -FilePath $script:logFile -Append
                $script:Profile_Script = 'AllUsers_' + (Split-Path -Path $PROFILE.AllUsersAllHosts -Leaf)
                Merge-Repository -SourcePath $PROFILE.AllUsersAllHosts -TargetPath "$script:myPShome\$script:Profile_Script" -MergePath "$script:adminHomeWPS\$script:Profile_Script"
            }
        }
    }
#endregion

#region Merge offline
    # otherwise, only merge repositories on local system
    if (-not $script:onServer) {

        Write-Output -InputObject 'Performing local (2-way) merges' | Tee-Object -FilePath $script:logFile -Append
        foreach ($module in $script:MyModules)
        {
            Write-Output -InputObject "Merging $module" | Tee-Object -FilePath $script:logFile -Append
            Merge-Repository -SourcePath $((Get-Module -Name $module -ListAvailable | Select-Object -Unique).ModuleBase) -TargetPath $env:USERPROFILE\Documents\GitHub\$module
        }

        # While we're at it merge any other common PS files, like profile scripts
        $script:ghMyScripts = Join-Path -Path $env:USERPROFILE -ChildPath 'Documents\GitHub\MyScripts'
        foreach ($psfile in @('CurrentUserCurrentHost','CurrentUserAllHosts','AllUsersCurrentHost','AllUsersAllHosts'))
        {
            if (Test-Path -Path $PROFILE.$psfile)
            {
                # Derive target path
                if ($psfile -like 'AllUsers*')
                {
                    $script:ScriptTargetPath = Join-Path -Path $script:ghMyScripts -ChildPath "AllUsers_$(Split-Path -Path $PROFILE.$psfile -Leaf)"
                }
                else
                {
                    $script:ScriptTargetPath = Join-Path -Path $script:ghMyScripts -ChildPath $(Split-Path -Path $PROFILE.$psfile -Leaf)
                }
                # Diff/Merge or copy the file
                if (Test-Path -Path $script:ScriptTargetPath)
                {
                    # Get file hashes and compare. If the hashes match, Compare-Object returns $false, so invert desired boolean using -not 
                    if ( -not [bool](Compare-Object -ReferenceObject (get-filehash -Path $PROFILE.$psfile) (get-filehash -Path $script:ScriptTargetPath) -Property Hash))
                    {
                        Write-Output -InputObject "Merging $psfile profile script" | Tee-Object -FilePath $script:logFile -Append
                        Merge-Repository -SourcePath $PROFILE.$psfile -TargetPath $script:ScriptTargetPath
                    }
                    else
                    {
                        Write-Output -InputObject "File hashes match; no action needed." | Tee-Object -FilePath $script:logFile -Append
                    }
                }
                else
                {
                    Write-Output -InputObject "Copying $psfile profile script" | Tee-Object -FilePath $script:logFile -Append
                    Copy-Item -Path $PROFILE.$psfile -Destination $script:ScriptTargetPath -PassThru
                }
            }
        }
    }
    #endregion

    Write-Output -InputObject "`n$(Get-Date -Format g) # Ending $($MyInvocation.MyCommand.Name)" | Tee-Object -FilePath $script:logFile -Append
    # ======== THE END ======================
    Write-Output -InputObject '' | Tee-Object -FilePath $script:logFile -Append

    # and then open GitHub desktop
    Set-ProcessState -ProcessName github -Action Start -Verbose
}
