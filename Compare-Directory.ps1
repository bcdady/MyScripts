# Compare-Directory.ps1
# https://gist.github.com/victorvogelpoel/6636754
# Compare files in one or more directories and return file difference results
# Victor Vogelpoel <victor@victorvogelpoel.nl>
# Sept 2013
#
# Disclaimer
# This script is provided AS IS without warranty of any kind. I disclaim all implied warranties including, without limitation,
# any implied warranties of merchantability or of fitness for a particular purpose. The entire risk arising out of the use or
# performance of the sample scripts and documentation remains with you. In no event shall I be liable for any damages whatsoever
# (including, without limitation, damages for loss of business profits, business interruption, loss of business information,
# or other pecuniary loss) arising out of the use of or inability to use the script or documentation.

[CmdletBinding(SupportsShouldProcess)]
param ()
Set-StrictMode -Version latest

Write-Verbose -Message "Declaring Function Add-FileComparisonAttribute"
function Add-FileComparisonAttribute {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [string]$DirectoryPath,
        [array]$ExcludeFile,
        [array]$ExcludeDirectory,
        [switch]$Recurse = $false
    )

    $relativeBasenameIndex = $DirectoryPath.ToString().Length

    # Get the files from the first path, Add MD5 hash & a relative path property for each file
    Get-ChildItem -Path $DirectoryPath -Exclude $ExcludeFile -Recurse:$Recurse | foreach { 

        # Test for directories and files that need to be excluded because of ExcludeDirectory
        if (($PSItem.PSIsContainer) -and ($ExcludeDirectory -like $PSItem.Name)) {
            Write-Verbose "Excluding Directory/container item `"$($PSItem.Fullname)`""
        }
        elseif ($PSItem.PSIsContainer) {
            Write-Verbose "Skipping Get-FileHash for Directory/container item `"$($PSItem.Name)`""
        } else {
            Write-Verbose "Adding `"$($PSItem.Name)`" to result set"
            # Added property(ies) to the object
            $hash = ""
            if (-not $PSItem.PSIsContainer) {
                Write-Debug -Message "`$hash = Get-FileHash -Algorithm MD5 -Path $($PSItem.FullName)"
                try {
                    $hash = Get-FileHash -Algorithm MD5 -Path $PSItem.FullName
                }
                catch [System.Exception] {
                    Write-Warning -Message "Failed: Get-FileHash -Algorithm MD5 -Path $($PSItem.Name)`n$Error[0]"
                    break
                }
            }
            Write-Verbose -Message "`$hash = $hash"
            $item = $PSItem |
                Add-Member -NotePropertyName "MD5Hash" -NotePropertyValue $hash.Hash -PassThru
            #     |
            #    Add-Member -NotePropertyName "ContainerName" -NotePropertyValue $(Split-Path -Path $(Split-Path -Path $PSItem.FullName -Parent) -Leaf) -PassThru | 
            Write-Output -InputObject $item # $($item | select Name,CompareName,MD5Hash)
        }
    }
}

Write-Verbose -Message "Declaring Function Compare-Directory"
function Compare-Directory {
    [OutputType([bool])]
	[CmdletBinding()]
	param (
		[Parameter(Mandatory=$true, position=0, ValueFromPipelineByPropertyName=$true, HelpMessage="The reference directory to compare one or more difference directories to.")]
		[System.IO.DirectoryInfo]$ReferenceDirectory,

		[Parameter(Mandatory=$true, position=1, ValueFromPipeline=$true, ValueFromPipelineByPropertyName=$true, HelpMessage="One or more directories to compare to the reference directory.")]
		[System.IO.DirectoryInfo]$DifferenceDirectory,

		[Parameter(ValueFromPipelineByPropertyName=$true, HelpMessage="Recurse the directories")]
		[switch]$Recurse,

		[Parameter(ValueFromPipelineByPropertyName=$true, HelpMessage="Files to exclude from the comparison")]
		[array]$ExcludeFile,

		[Parameter(ValueFromPipelineByPropertyName=$true, HelpMessage="Directories to exclude from the comparison")]
		[array]$ExcludeDirectory,

		[Parameter(ValueFromPipelineByPropertyName=$true, HelpMessage="Displays only the characteristics of compared objects that are equal.")]
		[switch]$ExcludeDifferent,
		
		[Parameter(ValueFromPipelineByPropertyName=$true, HelpMessage="Displays characteristics of files that are equal. By default, only characteristics that differ between the reference and difference files are displayed.")]
		[switch]$IncludeEqual,
		
		[Parameter(ValueFromPipelineByPropertyName=$true, HelpMessage="Passes the objects that differed to the pipeline.")]
		[switch]$PassThru
	)

	begin {
        # Get the contents of the base reference file/directory array for later comparison
		Write-Verbose -Message "Getting FileComparisonAttribute for reference directory $referenceDirectory"
        Write-Debug -Message "Add-FileComparisonAttribute -DirectoryPath $referenceDirectory -ExcludeFile $ExcludeFile -ExcludeDirectory $ExcludeDirectory -Recurse:$Recurse"
        $referenceDirectoryFiles = Add-FileComparisonAttribute -DirectoryPath $referenceDirectory -ExcludeFile $ExcludeFile -ExcludeDirectory $ExcludeDirectory -Recurse:$Recurse
        $results = $null
	}

	process {
		if ($DifferenceDirectory -and $referenceDirectoryFiles) {
			foreach($nextPath in $DifferenceDirectory) {
				# Get and compare the contents of the next file/directory array and return the results
		        Write-Verbose -Message "Getting FileComparisonAttributes Function for difference directory $nextpath"
		        Write-Debug -Message "Add-FileComparisonAttribute -DirectoryPath $nextpath -ExcludeFile $ExcludeFile -ExcludeDirectory $ExcludeDirectory -Recurse:$Recurse"
				$nextDifferenceFiles = Add-FileComparisonAttribute -DirectoryPath $nextpath -ExcludeFile $ExcludeFile -ExcludeDirectory $ExcludeDirectory -Recurse:$Recurse

				$results = @(Compare-Object -ReferenceObject $referenceDirectoryFiles -DifferenceObject $nextDifferenceFiles -ExcludeDifferent:$ExcludeDifferent -IncludeEqual:$IncludeEqual -PassThru:$PassThru -Property Name, MD5Hash | Select-Object -Property Name, LastWriteTime, MD5Hash, SideIndicator)

				if ( -not $PassThru) {
					foreach ($result in $results) {
						$path 		= $ReferenceDirectory
						$pathFiles	= $referenceDirectoryFiles
						if ($result.SideIndicator -eq "=>") {
							$path 		= $nextPath
							$pathFiles	= $nextDifferenceFiles
						}
					
						# Find the original item in the files array
						# $itemPath = $(Join-Path $path $result.CompareName) #.ToString().TrimEnd('\')
						$item = $pathFiles | Where-Object -FilterScript { $PSItem.fullName -eq $(Join-Path -Path $path -ChildPath $result.Name) }

						$result | Add-Member -NotePropertyName "Item" -NotePropertyValue $item
					}
				}
				# Write-Output $results
			}
		} else {
            Write-Warning -Message "Missing dependency: Unable to proceed without both `$DifferenceDirectory and `$referenceDirectoryFiles"
        }
	}

    end {
        # $differences = 0
        # $results | % {$differences+=1}
        # if ($differences -gt 0)
        if ((Get-Variable -Name results -ErrorAction SilentlyContinue) -and ($results.Count -gt 0)) {
            return $false
        } else {
            return $true
        }
    }
    <#
        .SYNOPSIS
            Compares a reference directory with one or more difference directories.		

        .DESCRIPTION
            Compare-Directory compares a reference directory with one ore more difference
            directories. Files and directories are compared both on filename and contents
            using a MD5hash.
            
            Internally, Compare-Object is used to compare the directories. The behavior
            and results of Compare-Directory is similar to Compare-Object.

        .PARAMETER  ReferenceDirectory
            The reference directory to compare one or more difference directories to.

        .PARAMETER  DifferenceDirectory
            One or more directories to compare to the reference directory.

        .PARAMETER Recurse
            Include subdirectories in the comparison.
            
        .PARAMETER ExcludeFile
            File names to exclude from the comparison.

        .PARAMETER ExcludeDirectory
            Directory names to exclude from the comparison. Directory names are 
            relative to the Reference of Difference Directory path

        .PARAMETER ExcludeDifferent
            Displays only the characteristics of compared files that are equal.
            
        .PARAMETER IncludeEqual
            Displays characteristics of files that are equal. By default, only 
            characteristics that differ between the reference and difference files 
            are displayed.

        .PARAMETER PassThru
            Passes the objects that differed to the pipeline. By default, this 
            cmdlet does not generate any output.

        .EXAMPLE
            Compare-Directory -reference "D:\TEMP\CompareTest\path1" -difference "D:\TEMP\CompareTest\path2" -ExcludeFile "web.config" -recurse
            
            Compares directories "D:\TEMP\CompareTest\path1" and "D:\TEMP\CompareTest\path2" recursively, excluding "web.config"
            Only differences are shown. Results:
            
            RelativeBaseName  MD5Hash                          SideIndicator Item                                                                     
            ----------------  -------                          ------------- ----                                                                     
            bin\site.dll      87A1E6006C2655252042F16CBD7FB41B =>            D:\TEMP\CompareTest\path2\bin\site.dll
            index.html        02BB8A33E1094E547CA41B9E171A267B =>            D:\TEMP\CompareTest\path2\index.html                                     
            index.html        20EE266D1B23BCA649FEC8385E5DA09D <=            D:\TEMP\CompareTest\path1\index.html                                     
            web_2.config      5E6B13B107ED7A921AEBF17F4F8FE7AF <=            D:\TEMP\CompareTest\path1\web_2.config                                   
            bin\site.dll      87A1E6006C2655252042F16CBD7FB41B =>            D:\TEMP\CompareTest\path2\bin\site.dll
            index.html        02BB8A33E1094E547CA41B9E171A267B =>            D:\TEMP\CompareTest\path2\index.html                                     
            index.html        20EE266D1B23BCA649FEC8385E5DA09D <=            D:\TEMP\CompareTest\path1\index.html                                     
            web_2.config      5E6B13B107ED7A921AEBF17F4F8FE7AF <=            D:\TEMP\CompareTest\path1\web_2.config                                   

        .EXAMPLE
            Compare-Directory -reference "D:\TEMP\CompareTest\path1" -difference "D:\TEMP\CompareTest\path2" -ExcludeFile "web.config" -recurse -IncludeEqual
            
            Compares directories "D:\TEMP\CompareTest\path1" and "D:\TEMP\CompareTest\path2" recursively, excluding "web.config".
            Results include the items that are equal:
            
            RelativeBaseName    MD5Hash                          SideIndicator Item                                                 
            ----------------    -------                          ------------- ----                                                 
            bin 	                                             ==            D:\TEMP\CompareTest\path1\bin                        
            bin\site2.dll       98B68D681A8D40FA943D90588E94D1A9 ==            D:\TEMP\CompareTest\path1\bin\site2.dll
            bin\site3.dll       9408C4B29F82260CBBA528342CBAA80F ==            D:\TEMP\CompareTest\path1\bin\site3.dll
            bin\site4.dll       0616E1FBE12D468F611F07768D70C2EE ==            D:\TEMP\CompareTest\path1\bin\site4.dll
            ...
            bin\site8.dll       87A1E6006C2655252042F16CBD7FB41B =>            D:\TEMP\CompareTest\path2\bin\site8.dll
            index.html          02BB8A33E1094E547CA41B9E171A267B =>            D:\TEMP\CompareTest\path2\index.html                 
            index.html          20EE266D1B23BCA649FEC8385E5DA09D <=            D:\TEMP\CompareTest\path1\index.html                 
            web_2.config        5E6B13B107ED7A921AEBF17F4F8FE7AF <=            D:\TEMP\CompareTest\path1\web_2.config               

        .EXAMPLE
            Compare-Directory -reference "D:\TEMP\CompareTest\path1" -difference "D:\TEMP\CompareTest\path2" -ExcludeFile "web.config" -recurse -ExcludeDifference
            
            Compares directories "D:\TEMP\CompareTest\path1" and "D:\TEMP\CompareTest\path2" recursively, excluding "web.config".
            Results only include the files that are equal; different files are excluded from the results.
            
        .EXAMPLE
            Compare-Directory -reference "D:\TEMP\CompareTest\path1" -difference "D:\TEMP\CompareTest\path2" -ExcludeFile "web.config" -recurse -Passthru
            
            Compares directories "D:\TEMP\CompareTest\path1" and "D:\TEMP\CompareTest\path2" recursively, excluding "web.config" and returns NO comparison
            results, but the different files themselves!
            
            FullName                                                                                                                                                                  
            --------                                                                                                                                                                  
            D:\TEMP\CompareTest\path2\bin\site3.dll
            D:\TEMP\CompareTest\path2\index.html
            D:\TEMP\CompareTest\path1\index.html
            D:\TEMP\CompareTest\path1\web_2.config

        .LINK
            Compare-Object
    #>
}
