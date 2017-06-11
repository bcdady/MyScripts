#requires -Version 3 -modules PowerShellGet
#===============================================================================
# NAME      : Find-NewModule.ps1
# LANGUAGE  : Windows PowerShell
# AUTHOR    : Bryan Dady
# DATE      : 06/06/2016
# COMMENT   : Thanks to @jsnover : https://twitter.com/jsnover/status/739869719532969984
#           Here's a 1-liner to find all the modules that have been updated this week:
#           $n=[datetime]::Now;fimo|?{($n-$_.PublishedDate).Days-le7}|ogv
#           $n = [datetime]::Now;fimo|Where-Object{($n-$_.PublishedDate).Days -le 1} | Format-List -Property Name,Description
#===============================================================================
[CmdletBinding()]
param ()

$age = [int]10
$today = [datetime]::Now

Write-Verbose -Message 'Defining function Find-NewModule' -Verbose
function Find-NewModule
{
    [cmdletbinding()]
    Param()

    Write-Verbose -Message 'Started function Find-ModuleUpdate'

    Write-Verbose -Message "Retrieving modules from powershellgallery.com, updated in the last $age days"
    # retrieve current gallery listing

    Try {
        $PSGallery = Find-Module -Repository PSGallery -ErrorAction Stop | Where-Object -FilterScript {($today-$_.PublishedDate).Days -le $age}
    }
    Catch {
        Write-Warning -Message 'Fatal error attempting to retrieve modules from powershellgallery.com'
        throw 'Failed to retrieve modules info from powershellgallery.com'
    }

    Write-Verbose -Message "Found $($PSGallery.length) new modules"

    Write-Verbose 'Checking for existing, installed modules'
    $InstalledModules = Get-InstalledModule; # Get-Module -ListAvailable

    Write-Verbose -Message "Got $($InstalledModules.length) installed modules"

    foreach ($module in $PSGallery) {

        Write-Verbose -Message "Checking for local version of $($module.name)"
        # compare matching object from online PSGallery, with list of local modules
        $foundLocal = $null
        if (-not ($module -in $InstalledModules)) {
            $module | Select-Object -Property Name,Version,PublishedDate,CompanyName,Author,Description
            $foundLocal = get-module -ListAvailable -Name $module.name | Select-Object -Property Name,Version,ModuleBase -ErrorAction SilentlyContinue
            $foundLocal
            if ($null -ne $foundLocal) {
                Write-Output -InputObject 'Found local module that can be replaced / upgraded from powershellgallery.com. Remove ''legacy'' module?'
                Remove-Module -Name $module.name -Confirm -ErrorAction SilentlyContinue
            }
            # prompt to install this new module?
        }
        else {
            $LocalModule = $InstalledModules | where{ $_.Name -eq $($module.name)}
            Write-Verbose -Message "Skipping already installed module $($LocalModule.name) ($($LocalModule.name), $($LocalModule.PublishedDate))"
        }
    } # end foreach

    Write-Verbose -Message 'Find-NewModule complete'
}