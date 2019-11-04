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

import argparse
import os
from os import path
import platform
import sys
import sysconfig
import time

IsVerbose = False
SleepTime = 5

print('Start : {}\n'.format(time.strftime('%Y %m %d %H:%M:%S %Z', time.localtime())))

# format output with some whitespace
print('\n # # Initiating python environment bootstrap #')
print(' ... from {}\n'.format(sys.argv[0]))

# http://www.effbot.org/librarybook/os.htm : where are we?
pwd = os.getcwd()
#print('')
#print('PWD is: ', pwd)

if 'HOME' in os.environ:
    HOME = os.environ['HOME']
else:
    print('HOME does not exist')
    # derive it from sysconfig 'userbase' with help from os path dirname
    HOME = os.path.abspath(os.path.dirname(sysconfig.get_config_var('userbase')))

print('HOME is \'{}\'\n'.format(HOME))

# if we ever need to confirm that the path is available on the filesystem, use: path.exists(HOME)

# Region HostOS
# Setup common variables for the shell/host environment

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
    hostOS = 'macOS'
    #hostOSCaption = ($(sw_vers -productName), ' ', $(sw_vers -productVersion)) # $(uname -mrs)
    
    if platform.mac_ver()[0].__len__():
        macOS_ver = platform.mac_ver()[0]
        # https://en.m.wikipedia.org/wiki/List_of_Apple_operating_systems#macOS
        macOS_names = dict({'10.15': 'Catalina', '10.14': 'Mojave', '10.13': "High Sierra", '10.12': 'Sierra', '10.11': 'El Capitan', '10.10': 'Yosemite'})
        hostOSCaption = 'Mac OS X {} {}'.format(macOS_ver, macOS_names[macOS_ver])
    
    # Check root or sudo 
    #IsAdmin =~ ?

else:
    IsLinux = True
    #hostOS = 'Linux'
    hostOSCaption = '{} {}'.format(platform.linux_distribution()[0], platform.linux_distribution()[1])
    
    # Check root or sudo 
    #IsAdmin =~ ?


print('\n # Python {} on {} - {} #\n'.format(sysconfig.get_config_var('py_version'), hostOSCaption, COMPUTERNAME))

#print('Setting environment HostOS to {}'.format(hostOS)
#$Env:HostOS = hostOS


#print('\n # # Python Environment Bootstrap Complete #\n')

""" 
    # Get the current locals().items() into a variable, as otherwise it changes during the subsequent for loop
    varList = dict(locals())
    # but remove varList as a key from itself
    #del varList['varList']

    print('List of final variables (locals()):')
    for k, v in varList.items():
        print(f'{k}={v}')
 """

# Uncomment the following line for testing / pausing between profile/bootstrap scripts
#time.sleep( SleepTime )

print('\nEnd : {}'.format(time.strftime('%Y %m %d %H:%M:%S %Z', time.localtime())))

#sys.exit(0)
