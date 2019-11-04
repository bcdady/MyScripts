#!/usr/local/bin/python3
# ===================================== #
# NAME      : userChrome.py
# LANGUAGE  : Python
# VERSION   : 3
# AUTHOR    : Bryan Dady
# UPDATED   : 11/4/2019 - Draft in pseudo-code
# INTRO     : Create and/or customize userChrome.css
#             Firefox’s userChrome.css file is a cascading style sheet (CSS) that applies to Firefox’s user interface.
#             Creating and customizing it allows you to change the appearance and layout of everything surrounding the webpage itself.
#             See this page for more information https://www.howtogeek.com/334716/how-to-customize-firefoxs-user-interface-with-userchrome.css/
# ===================================== #

import argparse
#import bootstrap
# Get common variables created by bootstrap
from bootstrap import HOME
from bootstrap import COMPUTERNAME
from bootstrap import hostOS
from bootstrap import hostOSCaption
from bootstrap import IsWindows
from bootstrap import IsLinux
from bootstrap import IsMacOS

import os
#from os import path
from pathlib import Path
import sys
import time

IsVerbose = False
SleepTime = 5

# MyScriptInfo
MyCommandPath = sys.argv[0]
MyCommandName = Path(MyCommandPath).name # requires 'from pathlib import Path'

print('\n ! Start {}: {}'.format(MyCommandName, time.strftime('%Y %m %d %H:%M:%S %Z', time.localtime())))

# userChrome Pseudo-code

# -- RFE!: create a function for dev/test, which takes 1 arg, and prints it's name and it's value
# -- RFE!: create a similar function for dev/test, which takes 1 arg of a dictionary, and prints the keys and values
print('hostOS: {}'.format(hostOS))

# Create userChrome.css file, only if necessary (does not exist by default)
# -- the file lives in the user's Firefox profile folder, which is a random / unique, per-user path
# -- 1. Detect/derive path to user's Firefox profile folder / example from Windows:  %APPDATA%\Mozilla\Firefox\Profiles\0y8i0p8f.default 
# -- confirm path is valid, with APPDATA derived from system/shell environment variable e.g. %APPDATA%\Mozilla\Firefox\Profiles\
# -- Ideally, there's only one subfolder (e.g. '0y8i0p8f.default') -- set it as var $profileRoot

if IsWindows:
    #APPDATA = os.environ['APPDATA']
    profileBase = os.path.expandvars('%APPDATA%\Mozilla\Firefox\Profiles')
else:
    # proceed as posix, for IsLinux or IsMacOS
    profileBase = os.path.expandvars('~\.local/Mozilla/Firefox/Profiles')


# -- 2. Look for $profileRoot\chrome\userChrome.css, if not exist, create it
profileRoot = os.path.join(profileBase, '*.default')
print('profileRoot join: {}'.format(profileRoot))
profileRoot = os.path.realpath(profileRoot)
print('profileRoot realpath: {}'.format(profileRoot))

# ! Whenever you edit your userChrome.css file, you will have to close all open Firefox windows and relaunch Firefox for your changes to take effect.
# Firefox also has a userContent.css file you can edit/user, in the same 'chrome' folder

print('\nEnd : {}\n'.format(time.strftime('%Y %m %d %H:%M:%S %Z', time.localtime())))
