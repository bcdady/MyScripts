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

# printing environment variables
print('')
print('Environment Variables:')
print(' # # #')
for k, v in os.environ.items():
    print(f'    {k} = {v}')
print(' # # #')
print('')

print('\nEnd : {}'.format(time.strftime('%Y %m %d %H:%M:%S %Z', time.localtime())))

#sys.exit(0)
