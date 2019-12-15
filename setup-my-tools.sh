#!/usr/bin/env bash
# ===================================== #
# NAME      : setup-my-tools.sh, is more descriptive that 'Brewstrap'
# LANGUAGE  : POSIX Shell
# AUTHOR    : Bryan Dady
# UPDATED   : 11/1/2019
# INTRO     : Make an otherwise uninitiated system ready for SRE: Install homebrew, ZSH, Oh-My-ZSH, VS Code, Python, PIP aws cli, etc. to a
# ===================================== #

#Create conditional functions for calling back to, if we determine (later) that our python, zsh, iterm, vscode or any other toolchain essentials are not (yet) available
# function install-homebrew-on-macOS
  # https://docs.brew.sh/Installation
  # confirm dependency xcode is installed
  # `xcode-select —-install`
  # `/usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"`
# function install-homebrew-on-linux
  # https://docs.brew.sh/Homebrew-on-Linux
  # `sh -c "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install.sh)"`
# add brew bin-root to PATH # append to .zshrc ? or ~/.profile: export PATH="/usr/local/bin:$PATH"

""" 
==> Homebrew has enabled anonymous aggregate formulae and cask analytics.
Read the analytics documentation (and how to opt-out) here:
  https://docs.brew.sh/Analytics

==> Homebrew is run entirely by unpaid volunteers. Please consider donating:
  https://github.com/Homebrew/brew#donations
==> Next steps:
- Install the Homebrew dependencies if you have sudo access:
  Debian, Ubuntu, etc.
    sudo apt-get install build-essential
  Fedora, Red Hat, CentOS, etc.
    sudo yum groupinstall 'Development Tools'
  See https://docs.brew.sh/linux for more information.
- Configure Homebrew in your ~/.profile by running
    echo 'eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)' >>~/.profile
- Add Homebrew to your PATH
    eval $(/home/linuxbrew/.linuxbrew/bin/brew shellenv)
- We recommend that you install GCC by running:
    brew install gcc
- Run `brew help` to get started
- Further documentation: 
    https://docs.brew.sh
Warning: /home/linuxbrew/.linuxbrew/bin is not in your PATH.
 """
# function install-python3 
  # https://docs.python-guide.org/starting/install3/osx/#doing-it-right
  # Install Python 3 and pip3 (from Homebrew)
  # `brew install python`

# function install-aws # pip3 install awscli2 
  # then to use aws cli, we have to configure permissions, such as follows (or via `aws2 configure`)
  # ! instead of storing AWS access keys / configurations in Env variables, use the aws-vault utility

# install-vscode # it looks like it's technically available in homebrew, but is that supported? # https://code.visualstudio.com/docs/setup/setup-overview

# function install-homebrew-cask # brew install cask
# function install-powershell-preview # brew cask install powershell-preview

# function install-ohmyzsh # $ sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# function install-golang # TBD

# if (Get-Command -Name Set-ConsoleTitle -ErrorAction SilentlyContinue) {
#     # Call Set-ConsoleTitle, from ProfilePal module
#     if ($IsVerbose) {print(''})
#     print(' # Set-ConsoleTitle >')
#     Set-ConsoleTitle
#     print(' # < Set-ConsoleTitle')
#     if ($IsVerbose) {print(''})
# }

# In case any intermediary scripts or module loads change our current directory, restore original path, before it's locked into the window title by Set-ConsoleTitle
#Set-Location $startingPath

# Loading ProfilePal Module, and only if successful, call Set-ConsoleTitle to customize the ConsoleHost window title
#Import-Module -Name ProfilePal
# if $?:
#     # Call Set-ConsoleTitle function from ProfilePal module
#     Set-ConsoleTitle
# }

