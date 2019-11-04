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
import os
from os import path
import platform
import sys
import sysconfig
import time

IsVerbose = False
SleepTime = 5

print('\n ! Start : {}'.format(time.strftime('%Y %m %d %H:%M:%S %Z', time.localtime())))

# format output with some whitespace
#print('\n # # Initiating python environment bootstrap #')
#print(' ... from {}\n'.format(sys.argv[0]))

# userChrome Pseudo-code

# Create userChrome.css file, only if necessary (does not exist by default)
# -- the file lives in the user's Firefox profile folder, which is a random / unique, per-user path
# -- 1. Detect/derive path to user's Firefox profile folder / example from Windows:  %APPDATA%\Mozilla\Firefox\Profiles\0y8i0p8f.default 
# -- confirm path is valid, with APPDATA derived from system/shell environment variable e.g. %APPDATA%\Mozilla\Firefox\Profiles\
# -- Ideally, there's only one subfolder (e.g. '0y8i0p8f.default') -- set it as var $profileRoot
# -- 2. Look for $profileRoot\chrome\userChrome.css, if not exist, create it



# ! Whenever you edit your userChrome.css file, you will have to close all open Firefox windows and relaunch Firefox for your changes to take effect.

# Firefox also has a userContent.css file you can edit/user, in the same 'chrome' folder

print('\nEnd : {}\n'.format(time.strftime('%Y %m %d %H:%M:%S %Z', time.localtime())))
