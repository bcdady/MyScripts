#!/usr/local/bin/python3
# ===================================== #
# NAME      : profile.py
# LANGUAGE  : Python
# VERSION   : 3
# AUTHOR    : Bryan Dady
# UPDATED   : 11/1/2019 - Convert from PowerShell Core
# INTRO     : python .profile script
# Created by New-Profile function of ProfilePal module
# ===================================== #

IsVerbose = False

 # Region: PowerShell Header
"""
    [CmdletBinding()]
    param ()
    #Set-StrictMode -Version latest

    # Uncomment the following 2 lines for testing profile scripts with Verbose output
    #'$VerbosePreference = ''Continue'''
    #$VerbosePreference = 'Continue'

    Write-Verbose -Message 'Detect -Verbose $VerbosePreference'
    switch ($VerbosePreference) {
        Stop             { $IsVerbose = $True }
        Inquire          { $IsVerbose = $True }
        Continue         { $IsVerbose = $True }
        SilentlyContinue { $IsVerbose = $False }
        Default          { if ('Verbose' -in $PSBoundParameters.Keys) {$IsVerbose = $True} else {$IsVerbose = $False} }
    }
    Write-Verbose -Message ('$VerbosePreference = ''{0}'' : $IsVerbose = ''{1}''' -f $VerbosePreference, $IsVerbose)

    # Region MyScriptInfo
        Write-Verbose -Message ('[{0}] Populating $MyScriptInfo' -f $MyInvocation.MyCommand.Name)
        $MyCommandName        = $MyInvocation.MyCommand.Name
        $MyCommandPath        = $MyInvocation.MyCommand.Path
        $MyCommandType        = $MyInvocation.MyCommand.CommandType
        $MyCommandModule      = $MyInvocation.MyCommand.Module
        $MyModuleName         = $MyInvocation.MyCommand.ModuleName
        $MyCommandParameters  = $MyInvocation.MyCommand.Parameters
        $MyParameterSets      = $MyInvocation.MyCommand.ParameterSets
        $MyRemotingCapability = $MyInvocation.MyCommand.RemotingCapability
        $MyVisibility         = $MyInvocation.MyCommand.Visibility

        if (($null -eq $MyCommandName) -or ($null -eq $MyCommandPath)) {
            # We didn't get a successful command / script name or path from $MyInvocation, so check with CallStack
            Write-Verbose -Message 'Getting PSCallStack [$CallStack = Get-PSCallStack]'
            $CallStack      = Get-PSCallStack | Select-Object -First 1
            # $CallStack | Select Position, ScriptName, Command | format-list # FunctionName, ScriptLineNumber, Arguments, Location
            $myScriptName   = $CallStack.ScriptName
            $myCommand      = $CallStack.Command
            Write-Verbose -Message ('$ScriptName: {0}' -f $myScriptName)
            Write-Verbose -Message ('$Command: {0}' -f $myCommand)
            Write-Verbose -Message 'Assigning previously null MyCommand variables with CallStack values'
            $MyCommandPath  = $myScriptName
            $MyCommandName  = $myCommand
        }

        #'Optimize New-Object invocation, based on Don Jones' recommendation: https://technet.microsoft.com/en-us/magazine/hh750381.aspx
        $properties = [ordered]@{
            'CommandName'        = $MyCommandName
            'CommandPath'        = $MyCommandPath
            'CommandRoot'        = Split-Path -Path $MyCommandPath -Parent
            'CommandType'        = $MyCommandType
            'CommandModule'      = $MyCommandModule
            'ModuleName'         = $MyModuleName
            'CommandParameters'  = $MyCommandParameters.Keys
            'ParameterSets'      = $MyParameterSets
            'RemotingCapability' = $MyRemotingCapability
            'Visibility'         = $MyVisibility
        }
        $MyScriptInfo = New-Object -TypeName PSObject -Property $properties -ErrorAction SilentlyContinue
        Write-Verbose -Message ('[{0}] $MyScriptInfo populated' -f $MyInvocation.MyCommand.Name)

        # Cleanup
        foreach ($var in $properties.Keys) {
            Remove-Variable -Name ('My{0}' -f $var) -Force -ErrorAction SilentlyContinue
        }
        Remove-Variable -Name properties
        Remove-Variable -Name var

        if ($IsVerbose) {
            Write-Verbose -Message '$MyScriptInfo:'
            $Script:MyScriptInfo
        }
 """
    #End Region

# Region python header : import
import sys
import os
import argparse

# example: http://www.effbot.org/librarybook/sys/sys-argv-example-1.py
print("script name (path) is", sys.argv[0])

if len(sys.argv) > 1:
    print("there are", len(sys.argv)-1, "arguments:")
    for arg in sys.argv[1:]:
        print(arg)
else:
    print("there are no arguments!")

print('')
print(' # Loading python profile')
print('')

# capture starting path so we can go back after other things below might move around
#$startingPath = $PWD.Path

if IsVerbose:
    print('It''s VERBOSE!!')
else:
    print('NOT verbose, but hey -- no errors either :)')

exit()


#Create conditional functions for calling back to, if we determine (later) that our python, zsh, iterm, vscode or any other toolchain essentials are not (yet) available
# function install-xcode # xcode-select —-install
# function install-homebrew # /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
# -- perhaps conditionally add brew bin-root to PATH # append to .zshrc ? or ~/.profile: export PATH="/usr/local/bin:$PATH"
# function install-python3 # Install Python 3 and pip3 (from Homebrew) # $ brew install python # https://docs.python-guide.org/starting/install3/osx/#doing-it-right
# function install-aws # pip3 install awscli2 
# then to use aws cli, we have to configure permissions, such as follows (or via `aws2 configure`)
  # ! instead of storing AWS access keys / configurations in Env variables, use the aws-vault utility

# function install-golang # TBD

#Region Bootstrap
    # Invoke Bootstrap.ps1, from the same root path as this $PROFILE script
    if (Get-Variable -Name 'myPS*' -ValueOnly -ErrorAction SilentlyContinue) {
        # python path variables have been initialized via a recent invocation of bootstrap.ps1
        print('')
        print('My python paths:')
        Get-Variable -Name 'myPS*' | Format-Table -AutoSize
    } else {
        # initialize variables, via bootstrap.ps1
        print ('(Test-Path -Path ./bootstrap.ps1): {0}' -f (Test-Path -Path ./Bootstrap.ps1))
        if (Test-Path -Path ./Bootstrap.ps1) {
            #print '. ./Bootstrap.ps1'
            . ./Bootstrap.ps1
        }

        if (Get-Variable -Name 'myPS*' -ValueOnly -ErrorAction SilentlyContinue) {
            # python path variables have been initialized via a recent invocation of bootstrap.ps1
            print('')
            print('My python paths:')
            Get-Variable -Name 'myPS*' | Format-Table -AutoSize
        } else {
            Write-Warning -Message './Bootstrap.ps1 may have encountered errors.'
        }
    }
#End Region

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

print ('$HostOS = ''{0}''' -f $HostOS)
# Detect host OS (as set in variables by Bootstrap) and proceed accordingly
if ($IsLinux) {
    #$Private:SubProfile = (Join-Path -Path (split-path -Path $MyScriptInfo.CommandPath) -ChildPath 'Microsoft.PowerShell_profile-Linux.ps1')
}

if ($IsMacOS) {
    #$Private:SubProfile = (Join-Path -Path (split-path -Path $MyScriptInfo.CommandPath) -ChildPath 'Microsoft.PowerShell_profile-macOS.ps1')
    
    # Set DNS resolver to Cloudflare secure DNS
    sudo networksetup -setdnsservers Wi-Fi 1.1.1.1

}

if ($IsWindows) {
    $Private:SubProfile = (Join-Path -Path (split-path -Path $MyScriptInfo.CommandPath) -ChildPath 'Microsoft.PowerShell_profile-Windows.ps1')
}

if ($IsVerbose) {print ''}
print ('$SubProfile = ''{0}''' -f $Private:SubProfile)

# Load/invoke OS specific profile sub-script
if (Test-Path -Path $SubProfile) {
    # dot-source it
    . $SubProfile
} else {
    throw ('Failed to locate OS specific profile sub-script: {0}' -f $SubProfile)
}
Remove-Variable -Name SubProfile -Force

# Here's an example of how convenient aliases can be added to your PS profile
New-Alias -Name rdp -Value Start-RemoteDesktop -ErrorAction Ignore

print ''
print ' ** To view additional available modules, run: Get-Module -ListAvailable'
print ' ** To view cmdlets available in a given module, run: Get-Command -Module <ModuleName>'

if ($IsVerbose) {print ''}
print ' # End of python $Profile CurrentUserCurrentHost #'

# For intra-profile/bootstrap script flow testing
if ($IsVerbose) {
    print 'Start-Sleep -Seconds 3'
    Start-Sleep -Seconds 3
}
 """
