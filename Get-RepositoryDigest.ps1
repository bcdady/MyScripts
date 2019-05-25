#!/usr/local/bin/pwsh
#Requires -Version 4
#========================================
# NAME      : Get-RepositoryDigest.ps1
# LANGUAGE  : PowerShell
# AUTHOR    : Bryan Dady
# UPDATED   : 03/14/2019
# COMMENT   : Returns a collection for per-file hash values for offline comparison of repositories
#========================================
[CmdletBinding()]
param()
Set-StrictMode -Version latest

# Uncomment the following 2 lines for testing profile scripts with Verbose output
#'$VerbosePreference = ''Continue'''
#$VerbosePreference = 'Continue'

Write-Verbose -Message 'Detect -Verbose $VerbosePreference'
switch ($VerbosePreference) {
    Stop             { $IsVerbose = $True }
    Inquire          { $IsVerbose = $True }
    Continue         { $IsVerbose = $True }
    SilentlyContinue { $IsVerbose = $False }
    Default          { if ('Verbose' -in $PSBoundParameters.Keys) {$IsVerbose = $True} else {$IsVerbose = $False} }
}
Write-Verbose -Message ('$VerbosePreference = ''{0}'' : $IsVerbose = ''{1}''' -f $VerbosePreference, $IsVerbose)

Write-Verbose -Message 'Importing function Get-RepositoryDigest'
function Get-RepositoryDigest {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [parameter(Position = 0, ValueFromPipelineByPropertyName )]
        [ValidateScript({
                try {
                    $Folder = Get-Item $_ -ErrorAction Stop
                } catch [System.Management.Automation.ItemNotFoundException] {
                    Throw [System.Management.Automation.ItemNotFoundException] "${_}"
                }
                if ($Folder.PSIsContainer) {
                    $True
                } else {
                    Throw [System.Management.Automation.ValidationMetadataException] "Path '${_}' is not a container (Directory)."
                }
            })]
        [Alias('Root')]
        [string]
        $Path = (Join-Path -Path $HOME -ChildPath "*\*PowerShell" -Resolve),
        [parameter(Position = 1, ValueFromPipelineByPropertyName )]
        [string]
        $Filter = '*.ps*1',
        [parameter(Position = 2, ValueFromPipelineByPropertyName )]
        [switch]
        $Recurse,
        # Algorithm is passed through to the Get-FileHash cmdlet and the supported values are based on what that cmdlet Supports
        [parameter(ValueFromPipelineByPropertyName)]
        [ValidateSet('SHA1', 'SHA256', 'SHA384', 'SHA512', 'MD5')]
        [string]
        $Algorithm = 'MD5'
    )

    begin {
        Write-Verbose -Message ('Root for comparison ($Path) is: {0}' -f $Path)

        # Transpose function parameters into $GCIparams, e.g. -Path . -File -Filter *.ps*1 -Recurse -Depth 1
        # Declare Hashtable variable for later Splatting through Get-ChildItem cmdlet
        $GCIparams = @{
            Path    = $Path
            Filter  = $Filter
            File    = $true
            Recurse = $Recurse
            # Depth = '1'
        }

        Write-Verbose -Message ('$GCIparams: {0}' -f (($GCIparams.Keys | ForEach-Object -Process {'-{0} {1}' -f $_, $GCIparams.$_}) -join ' '))
        Write-Verbose -Message ('$Algorithm: {0}' -f $Algorithm)

    }
    
    process {
        # For each file, return a custom object to the collection
        Get-ChildItem @GCIparams | ForEach-Object -Process {
            $objectAttributes = [ordered]@{
                'Name'          = $PSItem.Name
                'FullName'      = $PSItem.FullName
                'Path'          = $PSItem.FullName -replace ((Resolve-Path -Path $Path).Path -replace '\\','\\'),'[root]'
                'Length'        = $PSItem.Length
                'Hash'          = (Get-FileHash -Path $PSItem.FullName -Algorithm $Algorithm).Hash
                'LastWriteTime' = $PSItem.LastWriteTime
            }

            $File = New-Object -TypeName PSObject -Property $objectAttributes
            # Add AliasProperties to match property and alias names of FileInfo Type objects
            Add-Member -InputObject $File -MemberType AliasProperty -Name Size -Value Length -SecondValue System.ValueType
            Add-Member -InputObject $File -MemberType AliasProperty -Name DateModified -Value LastWriteTime -SecondValue System.String

            return $File
        }
    }
    
    end {
        Remove-Variable -Name GCIparams -ErrorAction SilentlyContinue
        Remove-Variable -Name File -ErrorAction SilentlyContinue
    }
<#
.SYNOPSIS
    Short description
.DESCRIPTION
    Long description
.EXAMPLE
    PS C:\> <example usage>
    Explanation of what the example does
.INPUTS
    Inputs (if any)
.OUTPUTS
    Output (if any)
.NOTES
    General notes
    Collect PowerShell artifact information into a variable
    $Digest = Get-RepositoryDigest -Path ~\Documents\WindowsPowerShell -Recurse
    Export to JSON file for offline comparison
    $Digest | ConvertTo-Json | Out-File -FilePath .\RepositoryDigest.json -Encoding utf8

    Import from JSON file for comparison
    $CompareDigest = (Get-Content -Path .\RepositoryDigest.json) -join "`n" | ConvertFrom-Json

    Compare 2 digest objects by their relative 'Path' property
    $Comparison = Compare-Object -ReferenceObject $Digest -DifferenceObject $CompareDigest -Property Path -PassThru -IncludeEqual

    Review comparison results by SideIndicator group
    $Comparison | Group-Object -Property SideIndicator
#>
}
