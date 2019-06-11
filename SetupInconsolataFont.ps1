<#

Author:
Version:
Version History:

Purpose: Download and setup Inconsolata font(s)

.LINK
https://twitter.com/fearthecowboy/status/595237159574970368?refsrc=email&s=11
#>

# Download
$Url = 'http://levien.com/type/myfonts/Inconsolata.otf'
$Path = "$HOME\Downloads\Inconsolata.otf"
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
