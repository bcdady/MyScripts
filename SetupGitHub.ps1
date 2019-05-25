<# Download and setup GitHub for Windows
.LINK
http://www.thomasmaurer.ch/2010/10/how-to-download-files-with-powershell/
#>
# Download
$Url = 'https://github-windows.s3.amazonaws.com/GitHubSetup.exe'
$Path = "$HOME\Downloads\GitHubSetup.exe"
#$Username = ''
#$Password = ''

# 1st: check if download path exists already, if so ... what should we do?
if (test-path $Path) {
    Write-Warning "Download destination $Path already exists."
} else {

    Write-Output -InputObject "Downloading $url to $path";

    # ? Enhance progress display?
    $WebClient = New-Object System.Net.WebClient
    #$WebClient.Credentials = New-Object System.Net.Networkcredential($null, $null); # ($Username, $Password)
    $WebClient.DownloadFile( "$url", "$path" )

}

# Confirm expected file is at target $path
try {
    $download = Test-Path -Path $Path -PathType Leaf
}
catch {
    Write-Warning "Unable to confirm $URL was downloaded to $Path"
    break;
}

Write-Debug $download -Debug;
if ($download -ne $null) {
    # If we think the file downloaded ok, let's try it out
    # * RFE * : add check for .exe extension; any other security considerations?
    Write-Output -InputObject "Starting installer: $Path";
    & $Path; # no silent / quiet install options are apparently available.
}
