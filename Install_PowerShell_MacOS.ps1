<#
    # Uninstall / re-install PowerShell on Mac
    # per https://github.com/PowerShell/PowerShell/blob/master/docs/installation/macos.md as of 2/18/18
    Uninstallation

    If you installed PowerShell with Homebrew, uninstallation is easy:

    brew cask uninstall powershell

    If you installed PowerShell via direct download, PowerShell must be removed manually:

    sudo rm -rf /usr/local/microsoft /Applications/PowerShell.app
    sudo rm -f /usr/local/bin/pwsh /usr/local/share/man/man1/pwsh.1.gz
    sudo pkgutil --forget com.microsoft.powershell

    If you installed PowerShell via binary archive, PowerShell must be removed manually.

    sudo rm -rf /usr/local/microsoft
    sudo rm -f /usr/local/bin/pwsh
#>
$err.clear()

& brew cask uninstall powershell
if ($err) {
    write-output ('Fatal error trying to update Homebrew: {0}' -f $err)
} else {
    Start-Sleep -Seconds 3
}

& sudo rm -rf /usr/local/microsoft /Applications/PowerShell.app
& sudo rm -f /usr/local/bin/pwsh /usr/local/share/man/man1/pwsh.1.gz
& sudo pkgutil --forget com.microsoft.powershell

Start-Sleep -Seconds 3

& sudo rm -rf /usr/local/microsoft
& sudo rm -f /usr/local/bin/pwsh

Start-Sleep -Seconds 6
$err.clear()

& brew update

if ($err) {
    write-Warning -Message ('Fatal error trying to update Homebrew: {0}' -f $err)
    write-Warning -Message 'Install HomeBrew and try again, or install PowerShell via another method (see https://github.com/PowerShell/PowerShell/blob/master/docs/installation/macos.md)'
} else {
    & brew tap caskroom/cask

    brew cask install powershell

    Start-Sleep -Seconds 3

    write-Output -InputObject 'Now, run "pwsh" to confirm Powershell core is installed.'

    write-Output -InputObject 'To update PowerShell via Homebrew, run:'
    write-Output -InputObject '     & brew update'
    write-Output -InputObject '     & brew cask upgrade powershell'
}
