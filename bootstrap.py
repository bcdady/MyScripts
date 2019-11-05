#!/usr/local/bin/python3
# ===================================== #
# NAME      : bootstrap.py
# LANGUAGE  : Python
# VERSION   : 3
# AUTHOR    : Bryan Dady
# UPDATED   : 11/4/2019 - Enhance IsVerbose behavior with print_var function
# INTRO     : To be loaded / dot-sourced from a python profile script, to establish (bootstrap) baseline consistent environment variables,
#             regardless of version, or operating system
# ===================================== #

import argparse
import os
import platform
import sys
import sysconfig
import time
from pathlib import Path

# setup global variables to export
global HOME
global COMPUTERNAME
global hostOS
global hostOSCaption
global IsWindows
global IsLinux
global IsMacOS

IsVerbose = False # True
SleepTime = 3

# MyScriptInfo
MyCommandPath = sys.argv[0]
MyCommandName = Path(MyCommandPath).name # requires 'from pathlib import Path'

# Only print Start and Stop Header/Footer when called directly, so as to not confuse use of argv[0]
if MyCommandName == 'bootstrap.py':
    print('\n Start {}: {}'.format(MyCommandName, time.strftime('%Y %m %d %H:%M:%S %Z', time.localtime())))

# http://www.effbot.org/librarybook/os.htm : where are we?
# pwd = os.getcwd()
#print('')
#print('PWD is: ', pwd)

# Region HostOS
# Setup common variables for the shell/host environment

IsWindows = False
IsLinux = False
IsMacOS = False
#IsAdmin = False
#IsServer = False

# -- print_var prints a label and a variable's value, if IsVerbose
def print_var(label, varname):
    if IsVerbose:
        print('< {} = \'{}\' >'.format(label, varname))

# -- RFE!: create a similar function for dev/test, which takes 1 arg of a dictionary, and prints the keys and values

# add blank line, only when IsVerbose
if IsVerbose: print('')

# Setup OS and version variables
COMPUTERNAME=platform.node()

hostOS = platform.system()
print_var('Platform: hostOS', hostOS)

hostOSCaption = platform.platform(aliased=1, terse=1)
print_var('Platform: hostOSCaption', hostOSCaption)

if sys.platform == "win32":
    # hostOS = 'Windows'
    IsWindows = True

    #if hostOSCaption -like '*Windows Server*':
    #    IsServer = True

    HOME = os.environ['USERPROFILE']

    # Check admin rights / role; same approach as Test-LocalAdmin function in Sperry module
    #IsAdmin = (([security.principal.windowsprincipal] [security.principal.windowsidentity]::GetCurrent()).isinrole([Security.Principal.WindowsBuiltInRole] 'Administrator'))

elif sys.platform == "mac" or sys.platform == "macos" or sys.platform == "darwin":
    IsMacOS = True
    hostOS = 'macOS'

    #if platform.mac_ver()[0].__len__():
    # Get the macOS major and minor version numbers (first 5 characters of first item in mac_ver dictionary)
    macOS_ver = platform.mac_ver()[0][0:5]
    # https://en.m.wikipedia.org/wiki/List_of_Apple_operating_systems#macOS
    macOS_names = dict({'10.15': 'Catalina', '10.14': 'Mojave', '10.13': "High Sierra", '10.12': 'Sierra', '10.11': 'El Capitan', '10.10': 'Yosemite'})
    hostOSCaption = 'Mac OS X {} {}'.format(macOS_ver, macOS_names[macOS_ver])

    HOME = os.environ['HOME']

    # Check root or sudo
    #IsAdmin =~ ?

else:
    IsLinux = True
    #hostOS = 'Linux'
    hostOSCaption = '{} {}'.format(platform.linux_distribution()[0], platform.linux_distribution()[1])

    HOME = os.environ['HOME']

    # Check root or sudo
    #IsAdmin =~ ?

print_var('HOME', HOME)

# if we ever need to confirm that the path is available on the filesystem, use: path.exists(HOME)
py_version =sysconfig.get_config_var('py_version')
print(' # Python {} on {} - {} #'.format(py_version, hostOSCaption, COMPUTERNAME))

# Save what we've determined here in shell/system environment variables, so they can be easily referenced from other py scripts/functions
# # 
# Verbose:
# print('\n Here are the persistent variables to import into the next script: ... ')
# print('from bootstrap import HOME')
# print('from bootstrap import COMPUTERNAME')
# print('from bootstrap import hostOS')
# print('from bootstrap import hostOSCaption')
# print('from bootstrap import IsWindows')
# print('from bootstrap import IsLinux')
# print('from bootstrap import IsMacOS')
#print('\n # # Python Environment Bootstrap Complete #\n')
# #

print_var('global variables','HOME, COMPUTERNAME, hostOS, hostOSCaption, IsWindows, IsLinux, IsMacOS')

"""
    # Get the current locals().items() into a variable, as otherwise it changes during the subsequent for loop
    varList = dict(locals())
    # but remove varList as a key from itself
    #del varList['varList']

    print('List of final variables (locals()):')
    for k, v in varList.items():
        print(f'{k}={v}')
 """

if MyCommandName == 'bootstrap.py':
    print(' End: {}\n'.format(time.strftime('%Y %m %d %H:%M:%S %Z', time.localtime())))

# When IsVerbose, pausing between profile/bootstrap scripts to aid in visual testing
if IsVerbose:
    print('(pause ...)')
    time.sleep( SleepTime )

#sys.exit(0)
