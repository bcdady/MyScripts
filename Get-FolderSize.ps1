#requires -version 2

<#
.SYNOPSIS
    Gets folder sizes using COM and with a fallback to robocopy.exe with the logging option,
    which makes it not actually copy or move files, but just list them, and the end
    summary result is parsed to extract the relevant data.

    This apparently is much faster than .NET and Get-ChildItem in PowerShell.

    The properties of the objects will be different based on which method is used, but
    the "TotalBytes" property is always populated if the directory size was successfully
    retrieved. Otherwise you should get a warning.

    BSD 3-clause license.

    Copyright (C) 2015, Joakim Svendsen
    All rights reserved.
    Svendsen Tech.

.PARAMETER Path
    Path or paths to measure size of.

.PARAMETER Precision
    Number of digits after decimal point in rounded numbers.

.PARAMETER RoboOnly
    Do not use COM, only robocopy, for always getting full details.

.EXAMPLE
    . .\Get-FolderSize.ps1
    PS C:\> 'C:\Windows', 'E:\temp' | Get-FolderSize

.EXAMPLE
    Get-FolderSize -Path Z:\Database -Precision 2

.EXAMPLE
    Get-FolderSize -Path Z:\Database -RoboOnly

.LINK
    http://www.powershelladmin.com/wiki/Get_Folder_Size_with_PowerShell,_Blazingly_Fast
#>
function Get-FolderSize {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)] [string[]] $Path,
        [int] $Precision = 4,
        [switch] $RoboOnly)
    begin {
        $FSO = New-Object -ComObject Scripting.FileSystemObject -ErrorAction Stop
        function Get-RoboFolderSizeInternal {
            [CmdletBinding()]
            param(
                # Paths to report size, file count, dir count, etc. for.
                [string[]] $Path,
                [int] $Precision = 4)
            begin {
                if (-not (Get-Command -Name robocopy -ErrorAction SilentlyContinue)) {
                    Write-Warning -Message "Fallback to robocopy failed because robocopy.exe could not be found. Path '$p'. $([datetime]::Now)."
                    return
                }
            }
            process {
                foreach ($p in $Path) {
                    Write-Verbose -Message "Processing path '$p' with Get-RoboFolderSizeInternal. $([datetime]::Now)."
                    $RoboCopyArgs = @('/L','/S','/NJH','/BYTES','/FP','/NC','/NDL','/TS','/XJ','/R:0','/W:0')
                    [datetime] $StartedTime = [datetime]::Now
                    [string] $Summary = Robocopy.exe $p NULL $RoboCopyArgs | Select-Object -Last 8
                    [datetime] $EndedTime = [datetime]::Now
                    [regex] $HeaderRegex = '\s+Total\s*Copied\s+Skipped\s+Mismatch\s+FAILED\s+Extras'
                    [regex] $DirLineRegex = 'Dirs\s*:\s*(?<DirCount>\d+)(?:\s*\d+){3}\s*(?<DirFailed>\d+)\s*\d+'
                    [regex] $FileLineRegex = 'Files\s*:\s*(?<FileCount>\d+)(?:\s*\d+){3}\s*(?<FileFailed>\d+)\s*\d+'
                    [regex] $BytesLineRegex = 'Bytes\s*:\s*(?<ByteCount>\d+)(?:\s*\d+){3}\s*(?<BytesFailed>\d+)\s*\d+'
                    [regex] $TimeLineRegex = 'Times\s*:\s*(?<TimeElapsed>\d+).*'
                    [regex] $EndedLineRegex = 'Ended\s*:\s*(?<EndedTime>.+)'
                    if ($Summary -match "$HeaderRegex\s+$DirLineRegex\s+$FileLineRegex\s+$BytesLineRegex\s+$TimeLineRegex\s+$EndedLineRegex") {
                        $TimeElapsed = [math]::Round([decimal] ($EndedTime - $StartedTime).TotalSeconds, $Precision)
                        New-Object PSObject -Property @{
                            Path = $p
                            TotalBytes = [decimal] $Matches['ByteCount']
                            TotalMBytes = [math]::Round(([decimal] $Matches['ByteCount'] / 1MB), $Precision)
                            TotalGBytes = [math]::Round(([decimal] $Matches['ByteCount'] / 1GB), $Precision)
                            BytesFailed = [decimal] $Matches['BytesFailed']
                            DirCount = [decimal] $Matches['DirCount']
                            FileCount = [decimal] $Matches['FileCount']
                            DirFailed = [decimal] $Matches['DirFailed']
                            FileFailed  = [decimal] $Matches['FileFailed']
                            TimeElapsed = $TimeElapsed
                            StartedTime = $StartedTime
                            EndedTime   = $EndedTime

                        } | Select-Object Path, TotalBytes, TotalMBytes, TotalGBytes, DirCount, FileCount, DirFailed, FileFailed, TimeElapsed, StartedTime, EndedTime
                    }
                    else {
                        Write-Warning -Message "Path '$p' output from robocopy was not in an expected format."
                    }
                }
            }
        }
    }
    process {
        foreach ($p in $Path) {
            Write-Verbose -Message "Processing path '$p'. $([datetime]::Now)."
            if (-not (Test-Path -Path $p -PathType Container)) {
                Write-Warning -Message "$p does not exist or is a file and not a directory. Skipping."
                continue
            }
            if ($RoboOnly) {
                Get-RoboFolderSizeInternal -Path $p -Precision $Precision
                continue
            }
            $ErrorActionPreference = 'Stop'
            try {
                $StartFSOTime = [datetime]::Now
                $TotalBytes = $FSO.GetFolder($p).Size
                $EndFSOTime = [datetime]::Now
                if ($TotalBytes -eq $null) {
                    Get-RoboFolderSizeInternal -Path $p -Precision $Precision
                    continue
                }
            }
            catch {
                if ($_.Exception.Message -like '*PERMISSION*DENIED*') {
                    Write-Verbose 'Caught a permission denied. Trying robocopy.'
                    Get-RoboFolderSizeInternal -Path $p -Precision $Precision
                    continue
                }
                Write-Warning -Message "Encountered an error while processing path '$p': $_"
                continue
            }
            $ErrorActionPreference = 'Continue'
            New-Object PSObject -Property @{
                Path = $p
                TotalBytes = [decimal] $TotalBytes
                TotalMBytes = [math]::Round(([decimal] $TotalBytes / 1MB), $Precision)
                TotalGBytes = [math]::Round(([decimal] $TotalBytes / 1GB), $Precision)
                BytesFailed = $null
                DirCount = $null
                FileCount = $null
                DirFailed = $null
                FileFailed  = $null
                TimeElapsed = [math]::Round(([decimal] ($EndFSOTime - $StartFSOTime).TotalSeconds), $Precision)
                StartedTime = $StartFSOTime
                EndedTime = $EndFSOTime
            } | Select-Object Path, TotalBytes, TotalMBytes, TotalGBytes, DirCount, FileCount, DirFailed, FileFailed, TimeElapsed, StartedTime, EndedTime
        }
    }
    end {
        [void][System.Runtime.Interopservices.Marshal]::ReleaseComObject($FSO)
        [gc]::Collect()
    }
}
