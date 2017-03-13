# Download software

# RFE :: Can this be cross-platform, in PS-Core?

$destinationDir = Join-Path -Path $HOME -ChildPath 'Downloads' -ErrorAction Stop

Function Initialize-PackageSettings
{
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # Parameter help description
        [Parameter(
            Mandatory,
            Position=0
        )]
        [Alias('FileName','json')]
        [String]
        $Name = 'bootstrap.json'
    )    
    Write-Debug -Message "`$script:Settings = (Get-Content -Path $(join-path -Path $(Split-Path -Path $((Get-PSCallStack).ScriptName | Sort-Object -Unique) -Parent) -ChildPath $Name)) -join ""``n"" | ConvertFrom-Json"
    $PackageSettingsPath = $(join-path -Path $(Split-Path -Path $PSCommandPath -Parent) -ChildPath $Name)
    try {
        $script:Settings = (Get-Content -Path $PackageSettingsPath) -join "`n" | ConvertFrom-Json
        Write-Verbose -Message 'Settings imported. Run Show-Settings to see details.' 
    }
    catch {
        throw "Critical Error loading settings from from $PackageSettingsPath"
    }
}

$script:packages = @{}
$script:Settings | ForEach-Object {
    Write-Debug -Message "$($PSItem.Name) = $($ExecutionContext.InvokeCommand.ExpandString($PSItem.Path))"
    $script:knownPaths.Add("$($PSItem.Name)",$ExecutionContext.InvokeCommand.ExpandString($PSItem.Path))
}

foreach ($download in $software.Keys) {
    $uri = $software.$download
    $file = $download
    if (-not (test-path -Path "$destinationDir\$file"))
    {
        write-output -InputObject "Downloading $file from $uri"
        $webclient.DownloadFile($uri,"$destinationDir\$file")

        if ($?)
        {
            start-sleep -seconds 1
            write-output -InputObject "Starting $file"
            & "$destinationDir\$file"

            start-sleep -seconds 5
        }
    }
    else
    {
        write-warning -Message "$destinationDir\$file already exists."
        write-output -InputObject '   To re-download / re-setup, first delete this file and try again.'
    }   
}
