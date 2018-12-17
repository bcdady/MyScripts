#requires -Version 3
#===============================================================================
# NAME      : Find-moduleupdates.ps1
# LANGUAGE  : Windows PowerShell
# AUTHOR    : Bryan Dady
# DATE      : 02/27/2017
# COMMENT   : Jeff Hicks' check-for-module-updates
# REFERENCE : # http://jdhitsolutions.com/blog/powershell/5441/check-for-module-updates/
#===============================================================================
[CmdletBinding()]
param ()

Write-Verbose -Message 'Defining function Find-ModuleUpdate' -Verbose
function Find-ModuleUpdate {
    [cmdletbinding()]
    Param()

    Write-Debug -Message 'Entered function Find-ModuleUpdate'

    Write-Output 'Getting all installed (PSGallery) modules'
    $InstalledModules = Get-InstalledModule; # Get-Module -ListAvailable

    Write-Verbose -Message "Got $($Modules.length) Installed Modules"

    #group to identify modules with multiple versions installed
    $g = $modules | group-object -Property name -NoElement | where-object -Property count -gt 1

    # Filter to modules from  PSGallery -- PS5 variant
    # $gallery = $modules.where({$_.repositorysourcelocation})

    Write-Output -Message 'Retrieving metadata of all available modules from powershellgallery.com'
    # retrieve current gallery listing

    Try {
        $PSGallery = Find-Module -Repository PSGallery -ErrorAction Stop
    }
    Catch {
        Write-Warning -Message 'Fatal error attempting to retrieve modules from powershellgallery.com'
        throw 'Failed to retrieve modules info from powershellgallery.com'
    }

    Write-Verbose -Message 'Comparing local to online versions'
    foreach ($module in $InstalledModules) {

        Write-Output -InputObject "Checking for updated version of $($module.name)"
        # compare matching object from online PSGallery, with this local module
        $online = $PSGallery | where-object -Property Name -EQ $module.name

        #compare versions
        if ($online.version -gt $module.version) {
            $UpdateAvailable = $True
        }
        else {
            $UpdateAvailable = $False
        }

        if ($UpdateAvailable) {
            #write a custom object to the pipeline
            [pscustomobject]@{
                Name = $module.name
                Update = $UpdateAvailable
                MultipleVersions = ($g.name -contains $module.name)
                OnlineVersion = $online.Version
                InstalledVersion = $module.Version
                InstalledDate = $module.InstalledDate
                UpdatedDate = $module.UpdatedDate
                # Path = $module.InstalledLocation
            }

            # RFE :: if $PSItem.Path like $HOME, then include -Scope CurrentUser / OR check for admin permissions

            Write-Output -InputObject "Getting updated module: $($module.name)`n"
            Update-Module -Name $module.name -RequiredVersion $online.version -Verbose

<#            Write-Verbose "Module path in -Scope CurrentUser: $($module.InstalledLocation -match ($HOME -replace '\\','\\'))" -Verbose
            
            if ($module.InstalledLocation -match ($HOME -replace '\\','\\')) {
                Update-Module -Name $module.name -RequiredVersion $online.version -Scope CurrentUser
            }
#>
        }
        else {
            [pscustomobject]@{
                Name = $module.name
                Update = $UpdateAvailable
                MultipleVersions = ($g.name -contains $module.name)
                OnlineVersion = $online.Version
                InstalledVersion = $module.Version
                InstalledDate = $module.InstalledDate
                UpdatedDate = $module.UpdatedDate
                # Path = $module.InstalledLocation
            }            
        } # end if 
    } # end foreach

    Write-Output 'Gallery Module Update check complete'
}