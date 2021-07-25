#!/usr/local/bin/python3
# ===================================== #
# NAME      : userChrome.py
# LANGUAGE  : Python
# VERSION   : 3
# AUTHOR    : Bryan Dady
# UPDATED   : 11/4/2019 - Enhance IsVerbose functionality, consistent with that of bootstrap.py
# INTRO     : Create and/or customize userChrome.css
#             Firefox’s userChrome.css file is a cascading style sheet (CSS) that applies to Firefox’s user interface.
#             Creating and customizing it allows you to change the appearance and layout of everything surrounding the webpage itself.
#             See this page for more information https://www.howtogeek.com/334716/how-to-customize-firefoxs-user-interface-with-userchrome.css/
#             As of Firefox (Quantum) ver. 69, Firefox no longer look for user CSS file automatically.
#             https://www.userchrome.org/firefox-changes-userchrome-css.html#fx69
# ===================================== #

import argparse
#import bootstrap
# Get global variables created by bootstrap
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
from pathlib import PurePath
from pathlib import PosixPath
import sys
import time
import re

IsVerbose = False # True
SleepTime = 5

# MyScriptInfo
MyCommandPath = sys.argv[0]
MyCommandName = Path(MyCommandPath).name # requires 'from pathlib import Path'

print('\n Start {}: {}'.format(MyCommandName, time.strftime('%Y %m %d %H:%M:%S %Z', time.localtime())))

# -- print_var prints a label and a variable's value, if IsVerbose
def print_var(label, varname):
    if IsVerbose:
        print('< {} = \'{}\' >'.format(label, varname))

# -- RFE!: create a similar function for dev/test, which takes 1 arg of a dictionary, and prints the keys and values

# userChrome Pseudo-code

print_var('hostOS', hostOS)

# Create userChrome.css file, only if necessary (does not exist by default)
# -- the file lives in the user's Firefox profile folder, which is a random / unique, per-user path
# -- 1. Detect/derive path to user's Firefox profile folder / example from Windows:  %APPDATA%\Mozilla\Firefox\Profiles\0y8i0p8f.default
# -- confirm path is valid, with APPDATA derived from system/shell environment variable e.g. %APPDATA%\Mozilla\Firefox\Profiles\
# -- Ideally, there's only one subfolder (e.g. '0y8i0p8f.default') -- set it as var $profileRoot

if IsWindows:
    # On Windows Firefox\Profiles reside under APPDATA = os.environ['APPDATA']
    profileBase = os.path.expandvars('%APPDATA%\Mozilla\Firefox\Profiles')
    # Also, it seems the default Profile folder name syntax is different across platforms
    regExp = '\S+\.default$'

if IsMacOS:
    # On macOS Firefox\Profiles reside under ~/Library/Application Support/Firefox/
    #profileBase = os.path.expandvars('~/Library/Application Support/Firefox/')
    profileBase = PosixPath('~/Library/Application Support/Firefox/')
    profileBase.expanduser()
    # Also, it seems the default Profile folder name syntax is different across platforms
    regExp = '\S+\.default-\d+'

if IsLinux:
    # On Linux Firefox\Profiles reside under ~/.mozilla/firefox
    profileBase = PosixPath('~/.mozilla/firefox')
    profileBase.expanduser()
    #profileBase = os.path.expandvars('~/.mozilla/firefox')
    # Also, it seems the default Profile folder name syntax is different across platforms
    regExp = '\S+\.default'

print_var('profileBase', profileBase)

profilePath = Path(profileBase)

# Iterate subdirectories')
for child in profilePath.iterdir():
    print_var('child', child)
    folderName = PurePath(child).name
    print_var('folderName', folderName)
    # evaluate the child directory name via RegExp (re)
    if re.search(regExp, folderName):
        profileRoot = Path(child)
        print_var('profileRoot', profileRoot)
    else:
        print('PANIC! unable to confirm Firefox default profile path for user.')
        quit(89)
# #

# -- 2. Look for $profileRoot\chrome\userChrome.css, if not exist, create it

# Determine if Firefox/Profiles/*.default/chrome/ exists, or needs to be created
chromePath = profileRoot.joinpath('chrome')
if chromePath.exists():
    print_var('chromePath', chromePath)
else:
    print_var('Make Dir chromePath', chromePath)
    chromePath.mkdir(exist_ok=True)

# Finish establishing path to ../chrome/userChrome.css
userChromePath = chromePath.joinpath('userChrome.css')

# if IsVersbose (testing), delete / remove / unlink it
if IsVerbose:
    print_var('[test step] Remove userChromePath', userChromePath)
    userChromePath.unlink(missing_ok=True)
    print_var('userChrome.css exist', userChromePath.exists())

if userChromePath.exists():
    print(' Found!: {}'.format(userChromePath))

else:
    print(' Creating {} ...'.format(userChromePath))
    # specify userChrome.css file contents
    userChromeData = '<!-- Firefox userChrome.css -->\n<!-- line 2 -->\n'
    # write those contents into the file
    userChromePath.write_text(userChromeData, encoding='utf-8') # , errors=None)
    print_var('userChromePath', userChromePath)

print_var('userChromePath exists', userChromePath.exists())

# #
# if IsVersbose, refresh, read / print contents of file
if IsVerbose or userChromePath.exists():
    #print(' Found!: {}'.format(userChromePath))
    #userChromePath = Path(userChromePath)
    print(' file contents:\n -----------------------------------------')
    print(userChromePath.read_text())
    print(' -----------------------------------------')
# #

# ! Whenever you edit your userChrome.css file, you will have to close all open Firefox windows and relaunch Firefox for your changes to take effect.
# Firefox also has a userContent.css file you can edit/user, in the same 'chrome' folder

print(' End: {}\n'.format(time.strftime('%Y %m %d %H:%M:%S %Z', time.localtime())))

# When IsVerbose, pausing between profile/bootstrap scripts to aid in visual testing
if IsVerbose:
    print('(pause ...)')
    time.sleep( SleepTime )
