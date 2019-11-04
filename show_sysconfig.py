#!/usr/local/bin/python3
# ===================================== #
# NAME      : environ.py
# LANGUAGE  : Python
# VERSION   : 3
# AUTHOR    : Bryan Dady
# UPDATED   : 11/1/2019 - reference working with system environment variables
# ===================================== #

import os
import sys
import time

print('Start {}: {}\n'.format(sys.argv[0], time.strftime('%Y %m %d %H:%M:%S %Z', time.localtime())))

# print python system config (dictionary)
print('')
print('Python ''Host''/Shell (system) config:')
print(' # # #')
for k, v in sysconfig.get_config_vars().items():
    print(f'    {k} = {v}')
print(' # # #')
print('')

# possibly interesting / useful sysconfig properties to reference
# access value example: "py_version_short" :: sysconfig.get_config_var('py_version_short')
# py_version = 3.6.8
# py_version_short = 3.6
# HOST_GNU_TYPE = x86_64-pc-linux-gnu

print('\nEnd : {}'.format(time.strftime('%Y %m %d %H:%M:%S %Z', time.localtime())))

#sys.exit(0)
