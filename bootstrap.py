#!/usr/local/bin/python3
# ===================================== #
# NAME      : bootstrap.py
# LANGUAGE  : Python
# VERSION   : 3
# AUTHOR    : Bryan Dady
# UPDATED   : 11/1/2019 - Convert from PowerShell Core
# INTRO     : To be loaded / dot-sourced from a python profile script, to establish (bootstrap) baseline consistent environment variables,
#             regardless of version, or operating system
# ===================================== #

IsVerbose = False
SleepTime = 5
 # Region PowerShell Header
"""
    [CmdletBinding()]
    param()

    # Uncomment the following 2 lines for testing profile scripts with Verbose output
    #'$VerbosePreference = ''Continue'''
    #$VerbosePreference = 'Continue'

    print('Detect -Verbose $VerbosePreference')
    switch ($VerbosePreference) {
        Stop             { IsVerbose = True }
        Inquire          { IsVerbose = True }
        Continue         { IsVerbose = True }
        SilentlyContinue { IsVerbose = False }
        Default          { if ('Verbose' -in $PSBoundParameters.Keys) {IsVerbose = True} else {IsVerbose = False} }
    }
    print('$VerbosePreference = ''{0}'' : IsVerbose = ''{1}''' -f $VerbosePreference, IsVerbose)

 # Region MyScriptInfo
    print('[{0}] Populating $MyScriptInfo' -f $MyInvocation.MyCommand.Name)
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
        print('Getting PSCallStack [$CallStack = Get-PSCallStack]')
        $CallStack      = Get-PSCallStack | Select-Object -First 1
        # $CallStack | Select Position, ScriptName, Command | format-list # FunctionName, ScriptLineNumber, Arguments, Location
        $myScriptName   = $CallStack.ScriptName
        $myCommand      = $CallStack.Command
        print('$ScriptName: {0}' -f $myScriptName)
        print('$Command: {0}' -f $myCommand)
        print('Assigning previously null MyCommand variables with CallStack values')
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
    print('[{0}] $MyScriptInfo populated' -f $MyInvocation.MyCommand.Name)

    # Cleanup
    foreach ($var in $properties.Keys) {
        Remove-Variable -Name ('My{0}' -f $var) -Force -ErrorAction SilentlyContinue
    }
    Remove-Variable -Name properties
    Remove-Variable -Name var

    if (IsVerbose) {
        print('$MyScriptInfo:')
        $Script:MyScriptInfo
    }
 # End Region
"""

# Region python header : import
import argparse
import os
from os import path
import platform
import sys
import time

print("Start : %s" % time.ctime())

# format output with some whitespace
print('')
print(' # # Initiating python environment bootstrap #')
print(' ... from', sys.argv[0])

# http://www.effbot.org/librarybook/os.htm : where are we?
pwd = os.getcwd()
print('')
print('PWD is: ', pwd)

# printing environment variables
print('')
print('Environment Variables:')
print(' # # #')
for k, v in os.environ.items():
    print(f'{k}={v}')
print(' # # #')
print('')

if 'HOME' in os.environ:
    print('HOME is {}'.format(os.environ['HOME']))
else:
    print('HOME does not exist')

print('')
# Region HostOS
# Setup common variables for the shell/host environment
# Using sys module
""" # comment block#
Get-Variable -Name Is* -Exclude ISERecent | FT

Name                           Value
----                           -----
IsAdmin                        False
IsCoreCLR                      True
IsLinux                        False
IsMacOS                        True
IsWindows                      False
""" # end of comment block#

# print(sys.platform)

IsWindows = False
IsLinux = False
IsMacOS = False
IsAdmin = False
IsServer = False

# Setup OS and version variables
COMPUTERNAME=platform.node()

print('Platform / hostOS is \'{}\''.format(platform.system()))
hostOS = platform.system() # 'Windows'


if sys.platform == "win32":
    IsWindows = True
    # hostOS = 'Windows'
    platform.win32_ver

    #hostOSInfo = Get-CimInstance -ClassName Win32_OperatingSystem -Property Caption, LastBootUpTime
    #LastBootUpTime = hostOSInfo.LastBootUpTime # @{Name="Uptime";Expression={((Get-Date)-$_.LastBootUpTime -split '\.')[0]}}
    #hostOSCaption = hostOSInfo.Caption -replace 'Microsoft ', ''
    #if hostOSCaption -like '*Windows Server*':
    #    IsServer = True

    # Check admin rights / role; same approach as Test-LocalAdmin function in Sperry module
    #IsAdmin = (([security.principal.windowsprincipal] [security.principal.windowsidentity]::GetCurrent()).isinrole([Security.Principal.WindowsBuiltInRole] 'Administrator'))

elif sys.platform == "mac" or sys.platform == "macos" or sys.platform == "darwin":
    IsMacOS = True

    # !RFE: enhance dynamic hostOS and hostOSCaption population and evaluation
    #hostOS = 'macOS'
    #hostOSCaption = ($(sw_vers -productName), ' ', $(sw_vers -productVersion)) # $(uname -mrs)
    hostOSCaption = '{}'.format(platform.mac_ver)

    print('')
#    print (' # {0} {1} {2} on {3} - {4} #' -f $ShellId, host.version.toString().substring(0,3), $PSEdition, hostOSCaption, COMPUTERNAME)

    # Check root or sudo 
    #IsAdmin =~ ?

else:
    IsLinux = True
    #hostOS = 'Linux'

    #distro = platform.linux_distribution()
    #hostOSCaption = '{} {}'.format(distro[0], distro[1])
    hostOSCaption = '{} {}'.format(platform.linux_distribution()[0], platform.linux_distribution()[1])
    
    # Check root or sudo 
    #IsAdmin =~ ?


#print('Setting environment HostOS to {}'.format(hostOS)
#$Env:HostOS = hostOS

#End Region HostOS

print('')

#Region Check $HOME
"""     # If running from a server / networked context, prefer non-local $HOME path
    if (IsServer -and (-not $InOneDrive)) {
        # Derive full path to user's $HOME and python folders
        print('IsServer = True; Checking if $HOME is on the SystemDrive')
        Write-Debug -Message ('$Home is: {0}.' -f $Home)
        $HomePath = Resolve-Path -Path $HOME
        print('$HomePath is: {0}.' -f $HomePath)
        # If $HOME is on the SystemDrive, then it's not the right $HOME we're looking for
        if ($Env:SystemDrive -eq $HomePath.Path.Substring(0,2)) {
            Write-Warning -Message ('Operating in a Server OS and $HOME ''{0}'' is on SystemDrive. Looking for a network HOME path' -f $HOME)
            # Detect / derive a viable (new) $HOME root, by looking at the HOMEDRIVE, HOMEPATH system variables
            $PreviousErrorActionPreference = $ErrorActionPreference
            $ErrorActionPreference = 'SilentlyContinue'
            if (Test-Path -Path ('{0}{1}' -f $Env:HOMEDRIVE, $Env:HOMEPATH)) {
                print('Determined {0}{1} ($Env:HOMEDRIVE+$Env:HOMEPATH) is available' -f $Env:HOMEDRIVE, $Env:HOMEPATH)
                $HomePath = Join-Path -Path $Env:HOMEDRIVE -ChildPath $Env:HOMEPATH
            } else {
                print('Determined {0}{1} ($Env:HOMEDRIVE+$Env:HOMEPATH) is NOT available; trying ''H:\''' -f $Env:HOMEDRIVE, $Env:HOMEPATH)
                if (Test-Path -Path (Join-Path -Path 'H:\' -ChildPath '*Documents')) {
                    $HomePath = 'H:\'
                } else {
                    Write-Warning -Message 'H:\ does not appear to contain a [My ]Documents folder, so it''s not a reliable $HOME path.'
                }
            }
            $ErrorActionPreference = $PreviousErrorActionPreference
            Remove-Variable -Name PreviousErrorActionPreference
        }

        # Next, (Re-)confirm a viable [My ]Documents subfolder, and update the $HomePath variable for later re-use/reference
        if (Test-Path -Path (Join-Path -Path $HomePath -ChildPath '*Documents' -Resolve)) {
            $HomeDocsPath = (Join-Path -Path $HomePath -ChildPath '*Documents' -Resolve)
            print('Confirmed $HomePath contains a Documents folder: {0}' -f $HomeDocsPath)
            if ($HOME -ne $HomePath) {
                # Update $HOME to match updated $HomePath
                print('Updating $HOME to $HomePath: {0}' -f $HomePath)
                Set-Variable -Name HOME -Value $HomePath -Scope Global -Force -ErrorAction Stop
            }
        } else {
            Write-Warning -Message 'Failed to confirm a reliable $HOME (user) folder. Consider updating $HOME and trying again.'
            break
        }
    }
 """
    # Bootstrap is intended to live next to User Profile (pwsh) scripts, so regardless of PSEdition (Core or Desktop), it's root should be $myPSHome
# HOME = os.environ['HOME']
# path.exists(HOME)

#    $myPSHome =$MyScriptInfo.CommandRoot

    #if IsWindows:
    #     $myPSHome = ('{0}\WindowsPowerShell' -f $HomeDocsPath)
    #     if ((HOME -like "$Env:SystemDrive*") -and ($PSEdition -eq 'Core')) {
    #         Write-Verbose -Message 'Using local PS Core path: ''python''.' -Verbose
    #         $myPSHome = ('{0}\python' -f $HomeDocsPath)
    #     }

"""         # In Windows, semicolon is used to separate entries in the PATH variable
        $Private:SplitChar = ';'

        #Define modules, scripts, and log folders within user's python folder, creating the SubFolders if necessary
        $myPSModulesPath = (Join-Path -Path $myPSHome -ChildPath 'Modules')
        if (-not (Test-Path -Path $myPSModulesPath)) {
            New-Item -Path $myPSHome -ItemType Directory -Name 'Modules'
        }
        Set-Variable -Name myPSModulesPath -Value $myPSModulesPath -Force -Scope Global

        $myPSScriptsPath = (Join-Path -Path $myPSHome -ChildPath 'Scripts')
        if (-not (Test-Path -Path $myPSScriptsPath)) {
            New-Item -Path $myPSHome -ItemType Directory -Name 'Scripts'
        }
        Set-Variable -Name myPSScriptsPath -Value $myPSScriptsPath -Force -Scope Global

        $myPSLogPath = (Join-Path -Path $myPSHome -ChildPath 'log')
        if (-not (Test-Path -Path $myPSLogPath)) {
            New-Item -Path $myPSHome -ItemType Directory -Name 'log'
        }
        Set-Variable -Name myPSLogPath -Value $myPSLogPath -Force -Scope Global

    } else {
        # Setup "MyPS" variables with python (pwsh) common paths for non-Windows / PS Core host
        # https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-core-on-linux?view=powershell-6#paths
        # User profiles will be read from ~/.config/python/profile.ps1 (and for our purposes, user Scripts should be in the same place)
        $myPSScriptsPath = "~/.config/python/scripts"
        if (-not (Test-Path -Path $myPSScriptsPath)) {
            New-Item -Path "~/.config/python/" -ItemType Directory -Name 'scripts'
        }
        Set-Variable -Name myPSScriptsPath -Value $myPSScriptsPath -Force -Scope Global

        # User modules will be read from ~/.local/share/python/Modules
        $myPSModulesPath = "~/.local/share/python/Modules"
        if (-not (Test-Path -Path $myPSModulesPath)) {
            New-Item -Path "~/.local/share/python" -ItemType Directory -Name 'Modules'
        }
        Set-Variable -Name myPSModulesPath -Value $myPSModulesPath -Force -Scope Global

        # In non-Windows OS, colon character is used to separate entries in the PATH variable
        $Private:SplitChar = ':'
        if (-not (Test-Path -Path $HOME)) {
            print('Setting $HOME to $myPSHome')
            Set-Variable -Name HOME -Value $(Split-Path -Path $myPSHome -Parent) -Force
        }
    }

    # Copy local variable myPSHome to Global scope
    Set-Variable -Name myPSHome -Value $myPSHome -Force -Scope Global

    print('$myPSHome is {0}' -f $myPSHome)
    if (Get-Variable -Name myPSHome) {
        if (Test-Path -Path myPSHome -ErrorAction SilentlyContinue) {
            print('')
            print ('PS .\> {0}' -f (Push-Location -Path $myPSHome -PassThru | Select-Object -Property Path).Path)
            print('')
        } else {
            Write-Warning -Message 'Failed to establish / locate path to user python directory. Creating default locations.'
            if (Test-Path -Path $myPSHome -IsValid -ErrorAction Stop) {
                New-Item -ItemType 'Directory' -Path ('{0}' -f $myPSHome) -Confirm
            } else {
                throw 'Fatal error confirming or setting up python user root: $myPSHome'
            }
        }
    } else {
        throw 'Fatal error: $myPSHome is empty or null'
    }
#End Region

  #Region ModulePath
    # check and conditionally update/fix PSModulePath
    print('MyPSModulesPath: {0}' -f $myPSModulesPath)

    # Check if $myPSModulesPath is in $Env:PSModulePath, and while we're at it, cleanup $Env:PSModulePath for duplicates
    Write-Debug -Message ('($myPSModulesPath -in @($Env:PSModulePath -split $SplitChar) = {0}' -f ($myPSModulesPath -in @($Env:PSModulePath -split $SplitChar)))
    $EnvPSModulePath = (($Env:PSModulePath.split($SplitChar)).trim('/')).trim('\') | Sort-Object -Unique
    if (($null -ne $myPSModulesPath) -and (-not ($myPSModulesPath -in $EnvPSModulePath))) {
        print('Adding Modules Path: {0} to $Env:PSModulePath' -f $myPSModulesPath) -Verbose
        $Env:PSModulePath = $($EnvPSModulePath -join('{0}')) + $('{0}{1}' -f $SplitChar, $myPSModulesPath)

        # post-update cleanup
        if (Test-Path -Path (Join-Path -Path $myPSScriptsPath -ChildPath 'Cleanup-ModulePath.ps1') -ErrorAction SilentlyContinue) {
            & $myPSScriptsPath\Cleanup-ModulePath.ps1
            print($Env:PSModulePath)
        }
    }
    Remove-Variable -Name SplitChar -ErrorAction SilentlyContinue
  #End Region ModulePath
 """

print("Almost done ... : %s" % time.ctime())

print('')
print(' # # Python Environment Bootstrap Complete #')
print('')

# Get the current locals().items() into a variable, as otherwise it changes during the subsequent for loop
varList = dict(locals())
# but remove varList as a key from itself
#del varList['varList']

print('List of final variables (locals()):')
for k, v in varList.items():
    print(f'{k}={v}')

print('')
# Uncomment the following line for testing / pausing between profile/bootstrap scripts
#time.sleep( SleepTime )

print("End : %s" % time.ctime())

sys.exit(0)
