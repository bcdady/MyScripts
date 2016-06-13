#requires -Version 2
#===============================================================================
# NAME      : PowerDiff.ps1
# LANGUAGE  : Windows PowerShell
# AUTHOR    : Bryan Dady
# DATE      : 03/04/2016
# COMMENT   : PowerShell script to automate kdiff3.exe
# EXAMPLE   : PS .\> .\PowerDiff.ps1 -SourcePath .\Modules\ProfilePal -TargetPath ..\GitHub\ProfilePal -MergePath 'H:\My Documents\WindowsPowerShell\Modules\ProfilePal'
#===============================================================================
function Merge-Repository 
{
#region Setup
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true,Position = 0)]
        [ValidateScript({Test-Path -Path $PSItem})]
        [Alias('SourcePath','A')]
        [string]
        $file1,

        [Parameter(Mandatory = $true,Position = 1)]
        [ValidateScript({Test-Path -Path $PSItem})]
        [Alias('TargetPath','B')]
        [string]
        $file2,

        [Parameter(Mandatory = $false,Position = 2)]
        [ValidateScript({Test-Path -Path $PSItem})]
        [Alias('MergePath','C')]
        [string]
        $file3
    )
    Set-StrictMode -Version latest
    $error.clear()
    $erroractionpreference = 'Continue' # shows error message, but continue
    # DEBUG MODE : $erroractionpreference = "Inquire"; "`$error = $error[0]"

    #========================================
    Write-Output -InputObject "$(Get-Date -Format g) # Starting $($MyInvocation.MyCommand.Name) $args"

    # Define path to local copy of kdiff3.exe
    $kdiff = Join-Path -Path $env:ProgramFiles -ChildPath 'KDiff3\kdiff3.exe'
    if ( -not (Test-Path -Path $kdiff -PathType Leaf)) {
        throw "Failed to find $kdiff"
    }

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
        'FileAntiPattern=*.orig;*.o;*.ob`;.git*;*.zip;copy-module.ps1;README.md',
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
        'SkipDirStatus=1',
        'SyncMode=1',
        'TrustDate=0',
        'TrustDateFallbackToBinary=0',
        'TrustSize=0',
        'TryHard=1',
        'WhiteSpaceEqual=0',
        'WindowStateMaximised=1'
    )
    $kdArgs = ' --merge --auto'+' --cs "'+$($kdiffConfig -join '" --cs "')+'"'

    # To handle spaces in paths, without triggering ValidateScript errors against the functions defined parameters, we copy the function paramters to internal only variables
    # kdiff file1 / 'A' = $SourcePath
    # kdiff file2 / 'B' = $TargetPath
    # kdiff file3 / 'C' = $MergePath
    if ($file1.Contains(' ')) {
        Write-Debug -Message "Wrapping `$SourcePath with single-quotes"
        $SourcePath = "'$file1'"
    } else {
        $SourcePath = $file1
    }

    if ($file2.Contains(' ')) {
        Write-Debug -Message "Wrapping `$TargetPath with single-quotes"
        $TargetPath = "'$file2'"
    } else {
        $TargetPath = $file2
    }

    if ($file3.Contains(' ')) {
        Write-Debug -Message "Wrapping `$MergePath with single-quotes"
        $MergePath = "'$file3'"
    } else {
        $MergePath = $file3
    }

#endregion

#region DoWork

    # Show what we're going to run on the console, then actually run it.
#    if ($MergePath) 
    write-output '[DEBUG]: Checking MergePath:'
    if ([bool]$MergePath)
    {
        Write-Debug -Message "[DEBUG] Detected MergePath : $MergePath"
        Write-Debug -Message "$kdiff $SourcePath $TargetPath $MergePath --output $SourcePath $kdArgs"
        Write-Output -InputObject "Merging $SourcePath <-- $TargetPath $MergePath"
        Start-Process -FilePath $kdiff -ArgumentList "$SourcePath $TargetPath $MergePath --output $SourcePath $kdArgs" -Wait
    # In a 3-way merge, kdiff3 only writes 1 merged output file. So, after the merge is complete, we copy the final / merged output to the other merged directories. 
        Copy-Item -Path $SourcePath -Destination $TargetPath -Recurse -Confirm
        Copy-Item -Path $SourcePath -Destination $MergePath  -Recurse -Confirm
        
    }
    else 
    {
        Write-Debug -Message '[DEBUG] No MergePath; 2-way merge'
        Write-Debug -Message "$kdiff $SourcePath $TargetPath $kdArgs"
        Write-Output -InputObject "Merging $SourcePath <-> $TargetPath"
        Start-Process -FilePath $kdiff -ArgumentList "$SourcePath $TargetPath $kdArgs" -Wait
        # In a 2-way merge, with SyncMode=1 kdiff3 can sync noth directories, so we can skip the Copy-Item cmdlet that's included in the 3-way merge above.
        # Copy-Item -Path $SourcePath -Destination $TargetPath -Container -Recurse -Confirm
    }

    #endregion
    #========================================
    Write-Output -InputObject "`n$(Get-Date -Format g) # Ending $($MyInvocation.MyCommand.Name)`n"
}

function Merge-MyPSFiles 
{
    Write-Output -InputObject "$(Get-Date -Format g) # Starting $($MyInvocation.MyCommand.Name) $args"

    # Thrd-Party PS Modules I like
    $3PModules = @('ISEScriptingGeek', 'ISESteroids', 'Patchy', 'Pester', 'PowerGist-ISE', 'PowershellBGInfo', 'PowerShellCookbook', 'ShowDscResource')
    # My own 'custom' modules
    $MyModules = @('EditModule', 'ProfilePal', 'PSLogger', 'Sperry') #, 'UpGuard')
    # EXAMPLE   : PS .\> .\PowerDiff.ps1 -SourcePath .\Modules\ProfilePal -TargetPath ..\GitHub\ -MergePath 'H:\My Documents\WindowsPowerShell\Modules\'
    # Technically, per kdiff3 HElp, the name of the directory-to-be-merged only needs to be specified once, when the all are the same, just at different root paths.

    # if 'online' at work, then we merge 3 repos, including to target H: drive
#region Merge at work
    if (Test-Path -Path '\\hcdata\homes$\gbci\BDady\My Documents\WindowsPowerShell') 
    {
    Write-Output -InputObject "Detected work network with 'home' drive. Performing 3-way merges"
        foreach ($module in $3PModules) 
        {
            Write-Output -InputObject "Merging $module"
            Merge-Repository -SourcePath $env:USERPROFILE\Documents\WindowsPowerShell\Modules\$module -TargetPath "\\hcdata\homes`$\gbci\BDady\My Documents\WindowsPowerShell\Modules\$module'" -MergePath \\hcdata\apps\IT\PowerShell-Modules\$module
        }

        foreach ($module in $MyModules) 
        {
            Write-Output -InputObject "Merging $module"
            Merge-Repository -SourcePath $env:USERPROFILE\Documents\WindowsPowerShell\Modules\$module -TargetPath "\\hcdata\homes`$\gbci\BDady\My Documents\WindowsPowerShell\Modules\$module'" -MergePath \\hcdata\apps\IT\PowerShell-Modules\$module
        }
        # While we're at it merge any other common PS files, like profile scripts
        if (Test-Path -Path $PROFILE.CurrentUserCurrentHost) 
        {
            Write-Output -InputObject 'Merging CurrentUserCurrentHost profile script'
            $Profile_Script = Split-Path -Path $PROFILE.CurrentUserCurrentHost -Leaf
            Merge-Repository -SourcePath $PROFILE.CurrentUserCurrentHost -TargetPath "\\hcdata\homes`$\gbci\BDady\My Documents\WindowsPowerShell\$Profile_Script" -MergePath "\\hcdata\homes`$\gbci\BDady\My Documents\WindowsPowerShell\$Profile_Script"
        }
        elseif (Test-Path -Path $PROFILE.CurrentUserAllHosts)
        {
            Write-Output -InputObject 'Merging CurrentUserAllHosts profile script'
            $Profile_Script = Split-Path -Path $PROFILE.CurrentUserCurrentHost -Leaf
            Merge-Repository -SourcePath $PROFILE.CurrentUserAllHosts -TargetPath "\\hcdata\homes`$\gbci\BDady\My Documents\WindowsPowerShell\$Profile_Script" -MergePath "\\hcdata\homes`$\gbci\BDady\My Documents\WindowsPowerShell\$Profile_Script"
        }
        elseif (Test-Path -Path $PROFILE.AllUsersCurrentHost) 
        {
            Write-Output -InputObject 'Merging AllUsersCurrentHost profile script'
            $Profile_Script = 'AllUsers_' + (Split-Path -Path $PROFILE.AllUsersCurrentHost -Leaf)
            Merge-Repository -SourcePath $PROFILE.AllUsersCurrentHost -TargetPath "\\hcdata\homes`$\gbci\BDady\My Documents\WindowsPowerShell\$Profile_Script" -MergePath "\\hcdata\homes`$\gbci\BDady\My Documents\WindowsPowerShell\$Profile_Script"
        }
        elseif (Test-Path -Path $PROFILE.AllUsersAllHosts) 
        {
            Write-Output -InputObject 'Merging AllUsersAllHosts profile script'
            $Profile_Script = 'AllUsers_' + (Split-Path -Path $PROFILE.AllUsersAllHosts -Leaf)
            Merge-Repository -SourcePath $PROFILE.AllUsersAllHosts -TargetPath "\\hcdata\homes`$\gbci\BDady\My Documents\WindowsPowerShell\$Profile_Script" -MergePath "\\hcdata\homes`$\gbci\BDady\My Documents\WindowsPowerShell\$Profile_Script"
        }
    }
#endregion
    else
    {
    # otherwise, only merge repositories on local USERPROFILE
        Write-Output -InputObject 'Work network NOT detected. Performing local 2-way merges'
        foreach ($module in $MyModules) 
        {
            Write-Output -InputObject "Merging $module"
            Merge-Repository -SourcePath $env:USERPROFILE\Documents\WindowsPowerShell\Modules\$module -TargetPath $env:USERPROFILE\Documents\GitHub\$module
        }
    }

#    if ((Read-Host -Prompt "Type 'YES' and click [Enter] to merges custom modules in reverse (local only)...") -eq 'YES') {
#        if (Test-Path -Path '\\hcdata\homes$\gbci\BDady\My Documents\WindowsPowerShell') 
#        {
#        Write-Output -InputObject "Detected work network with 'home' drive. Performing 3-way merges"
#            foreach ($module in $3pModules) 
#            {
#                Write-Output -InputObject "Reverse merging $module"
#                Merge-Repository -SourcePath $env:USERPROFILE\Documents\WindowsPowerShell\Modules\$module -TargetPath "\\hcdata\homes`$\gbci\BDady\My Documents\WindowsPowerShell\Modules\$module'"
#            }
#
#            foreach ($module in $MyModules) 
#            {
#                Write-Output -InputObject "Reverse merging $module"
#                Merge-Repository -SourcePath $env:USERPROFILE\Documents\GitHub\$module -TargetPath $env:USERPROFILE\Documents\WindowsPowerShell\Modules\
#            }
#        }
#        else
#        {
#        # otherwise, only merge repositories on local USERPROFILE
#            Write-Output -InputObject 'Work network NOT detected. Performing local 2-way merges'
#            foreach ($module in $MyModules) 
#            {
#                Write-Output -InputObject "Reverse merging $module"
#                Merge-Repository -SourcePath $env:USERPROFILE\Documents\GitHub\$module -TargetPath $env:USERPROFILE\Documents\WindowsPowerShell\Modules\
#            }
#        }    
#    }

    #========================================
    Write-Output -InputObject "`n$(Get-Date -Format g) # Ending $($MyInvocation.MyCommand.Name)"
}
