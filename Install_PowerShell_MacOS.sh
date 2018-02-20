#!/bin/bash
############################################################################
# Uninstall / re-install PowerShell on Mac
# per https://github.com/PowerShell/PowerShell/blob/master/docs/installation/macos.md as of 2/18/18
#
# Steps performed by this script, in order:
# * Try to uninstall PowerShell via Homebrew
# * Delete (rm) known PowerShell directories, in case PowerShell was/had been installed via pkg
# * Delete (rm) known PowerShell directories, in case PowerShell was/had been installed via binary
# * Try to re-install PowerShell via Homebrew, after ensuring that Homebrew is updated
############################################################################

# Set UNINSTALL="TRUE" for force deletion of any existing PowerShell directories
UNINSTALL='FALSE'

# To install PowerShell Core 6.0+ via Homebrew, local Mac OS must be at least 10.12
req_version='12'

# Detect OS version and confirm OS name
product_name=$(sw_vers -productName)
product_version=$(sw_vers -productVersion)
os_vers=( ${product_version//./ } )
major_version="${os_vers[0]}"
minor_version="${os_vers[1]}"

clear
echo ''
echo '*** Install PowerShell Core on macOS (via Homebrew) ***'
echo ''
echo "Detected Host OS: $product_name ${major_version}.${minor_version}"
homebrew_version="$(brew --version | grep -o "\d\.\d\.\d")"

# To avoid/workaround decimal comparisons, we assume OSX 10.n and only compare minor versions
if [ "${minor_version}" -lt "${req_version}" ]; then
    echo " *** Warning: $product_name ${major_version}.${minor_version} not supported for PowerShell package management via Homebrew Cask ***"
fi
echo ''
sleep 2

if [ $UNINSTALL = "TRUE" ]; then
    echo "UNINSTALL: $UNINSTALL"

    if [[ $homebrew_version ]]; then
        echo "${homebrew_version}"
        echo 'Try to uninstall PowerShell via Homebrew'
        brew cask uninstall powershell
    #else
    #    echo 'Homebrew not found.'
    fi
    echo 'Delete known PowerShell directories'
    sudo rm -rf /usr/local/microsoft /Applications/PowerShell.app
    sleep 1
    sudo rm -f /usr/local/bin/pwsh /usr/local/share/man/man1/pwsh.1.gz
    sleep 1
    sudo pkgutil --forget com.microsoft.powershell
    sleep 1

    sudo rm -rf /usr/local/microsoft
    sleep 1
    sudo rm -f /usr/local/bin/pwsh
else
    echo "UNINSTALL: $UNINSTALL"
fi

if [[ $homebrew_version ]]; then
    echo 'Try to re-install PowerShell via Homebrew'
    echo 'brew update'
    brew update
    echo ''
    echo 'brew tap caskroom/cask'
    brew tap caskroom/cask
    echo ''
    echo 'brew cask install powershell'
    brew cask install powershell
    echo ''
else
    # PWSHMACURL='https://github.com/PowerShell/PowerShell/releases/download/v6.0.1/powershell-6.0.1-osx-x64.tar.gz'
    # PWSHMACVER='6.0.1'
    # Installation via Binary Archive
    echo 'Homebrew not found. You may want to edit this script in order to try again and Install via Binary Archive method'
    # echo ''

    # # Download the powershell '.tar.gz' archive
    # temp_file="/tmp/powershell.tar.gz"
    # if [ -f "$temp_file" ]
    # then
    #     echo 'powershell.tar.gz downloaded.'
    # else
    #     echo "Downloading powershell.tar.gz from ${PWSHMACURL}."
    #     curl -L -o /tmp/powershell.tar.gz $PWSHMACURL
    # fi

    # # Create the target folder where powershell will be placed
    # target_dir="/usr/local/microsoft/powershell/$PWSHMACVER"
    # if ! [ -d "$target_dir" ]; then
    # #    echo "Confirmed folder ${target_dir} exists."
    # #else
    #     echo "Creating PowerShell folder ${target_dir}."
    #     sudo mkdir -p $target_dir
    # fi

    # # Expand powershell to the target folder
    # echo 'Expand powershell archive.'
    # sudo tar zxf /tmp/powershell.tar.gz -C $target_dir
    # echo ''

    # # Confirm the powershell archive expanded to the target folder
    # target_file="$target_dir/pwsh"
    # if [ -f "$target_file" ]; then
    #     echo "Confirmed ${target_file} exists."

    #     # Set execute permissions
    #     echo 'Set execute permissions'
    #     sudo chmod +x "${target_file}"
    #     echo ''

    #     # Create the symbolic link that points to pwsh
    #     echo 'Creating symbolic link for pwsh.'
    #     sudo ln -s $target_file /usr/local/bin/pwsh
    # else
    #     echo "*** WARNING! Something didn't go as expected with expanding the archive. ***"
    # fi
fi

echo '*** Done! : running pwsh -version to confirm Powershell is installed. ***'
pwsh -version

if [ "${minor_version}" -ge "${req_version}" ]; then
    echo 'To update PowerShell via Homebrew, run:'
    echo '   brew update'
    echo '   brew cask upgrade powershell'
    echo ''
fi
