# Download software

# RFE :: Can this be cross-platform, in PS-Core?

$destinationDir = Join-Path -Path $HOME -ChildPath 'Downloads' -ErrorAction Stop
$webclient = New-Object System.Net.WebClient

# Make this a repeatable function  / looping call
$software = @{
    'GitHubSetup.exe'               = 'https://github-windows.s3.amazonaws.com/GitHubSetup.exe'
    'VSCodeSetup-stable.exe'        = 'https://go.microsoft.com/fwlink/?LinkID=623230'
    'VSCodeSetup-insider.exe'       = 'https://go.microsoft.com/fwlink/?LinkId=723965'
    'BraveSetup-x64.exe'            = 'https://laptop-updates.brave.com/latest/winx64'
    'KDiff3-64bit-Setup_latest.exe' = 'http://downloads.sourceforge.net/project/kdiff3/kdiff3/0.9.98/KDiff3-64bit-Setup_0.9.98-2.exe?r=https%3A%2F%2Fsourceforge.net%2Fprojects%2Fkdiff3%2Ffiles%2Fkdiff3%2F&ts=1477252886&use_mirror=heanet'
}
#     'KDiff3-64bit-Setup_latest.exe' = 'https://sourceforge.net/projects/kdiff3/files/latest/download?source=files'

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
