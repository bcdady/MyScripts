# from: https://support.upguard.com/hc/en-us/articles/204164654-Scan-Options-Extracting-IIS-Website-Information

# test if WebAdministation Moduleavailable; suggests IIS feature is installed

if ('WebAdministration' -in (Get-Module -ListAvailable).Name) {
    Write-Output -InputObject 'Importing Module WebAdministration'
    Import-Module -Name WebAdministration

    $WebConfigFile = Get-WebConfigFile

    Write-Output -InputObject "Got WebConfigFile: $WebConfigFile"
}

function Get-IISconfig {
    [cmdletbinding( SupportsShouldProcess = $True )]
    Param(
        [Parameter(Mandatory = $True,
            Position = 0,
            ValueFromPipeline = $True,
            HelpMessage = 'Path to IIS config XML file.')]
        [ValidateScript({ Test-Path $PSItem })]
        [string]
        $Path
    )
    Set-PSDebug -Trace 2

    Write-Debug -Message "Starting Get-IISconfig -Path $Path"

    $doc = (Get-Content $Path) -as [Xml]
    if ($?) {
        Write-Debug -Message "Parsed `$Path content as XML: $doc"
    }

    Write-Output -InputObject 'Get-Member for $Path as XML'

    $doc | Get-Member

    Write-Output -InputObject 'build custom PowerShell IIS info object'

    $output = @()
    foreach($site in $doc.configuration.'system.applicationHost'.sites.site) {
        $tempObj = New-Object -TypeName PSObject
        $tempObj | Add-Member -MemberType NoteProperty -Name Name -Value $site.name
        $tempObj | Add-Member -MemberType NoteProperty -Name Id -Value $site.id
        $tempObj | Add-Member -MemberType NoteProperty -Name ServerAutoStart -Value $site.serverAutoStart
    }

    foreach($ap in $doc.configuration.'system.applicationHost'.applicationPools.add) {
        $tempObj = New-Object -TypeName PSObject
        $tempObj | Add-Member -MemberType NoteProperty -Name ApplicationPool -Value $ap.name
        $tempObj | Add-Member -MemberType NoteProperty -Name ApplicationPool.Version -Value $ap.managedRuntimeVersion
        $tempObj | Add-Member -MemberType NoteProperty -Name ManagedPipelineMode -Value $ap.managedPipelineMode
        $tempObj | Add-Member -MemberType NoteProperty -Name AutoStart -Value $ap.autoStart
    }
 
    foreach($vdir in $site.application.virtualDirectory) {
        $tempObj | Add-Member -MemberType NoteProperty -Name VirtualDirectory -Value "$($vdir.path)"
        $tempObj | Add-Member -MemberType NoteProperty -Name PhysicalPath -Value $vdir.physicalPath
    }

    $output += $tempObj

    return $output
}

if ($WebConfigFile) {
    Write-Output -InputObject "Get-IISconfig -Path $WebConfigFile"
    Get-IISconfig -Path $WebConfigFile
} else {
    Write-Output -InputObject "Get-IISconfig -Path '$env:SystemRoot\inetsrv\config\applicationHost.config'"
    Get-IISconfig -Path "$env:SystemRoot\inetsrv\config\applicationHost.config"
}

