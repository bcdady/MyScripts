#!/bin/sh
############################################################################
# Reset a OneDrive app which is misbehaving, such as not sync'ing.
# The following steps were recommended by Microsoft OneDrive support, and tested successful by the author,
# with no side effects, othen than having to re-sign in to the OneDrive app, and reselecting certain directories to exclude form sync
#
#  Steps performed by this script, in order:
# Quit the OneDrive application if it's running.
# Delete ~/Library/Containers/com.microsoft.OneDrive-mac.
# Delete ~/Library/Containers/com.microsoft.OneDriveLauncher (if it exists).
# Run the command killall -SIGTERM cfprefsd.
# Restart the OneDrive application.
############################################################################
clear
echo ""
echo "*** Reset OneDrive for Mac ***"
echo ""
sleep 1
echo "Quit the OneDrive process(es)"
# http://osxdaily.com/2014/09/05/gracefully-quit-application-command-line/
osascript -e 'quit app "OneDrive"'

# OR, if necesarry ...
# https://stackoverflow.com/questions/3510673/find-and-kill-a-process-in-one-line-using-bash-and-regex
# kill $(ps aux | grep  -ie '[O]neDrive' | awk '{print $2}')
sleep 1

echo "Delete ~/Library/Containers/com.microsoft.OneDrive-mac"
rm -Rf ~/Library/Containers/com.microsoft.OneDrive-mac
sleep 1

echo "Delete ~/Library/Containers/com.microsoft.OneDriveLauncher" # (if it exists)
rm -Rf ~/Library/Containers/com.microsoft.OneDriveLauncher
sleep 1

echo "Restart the OneDrive application"
killall -SIGTERM cfprefsd
sleep 1
# http://osxdaily.com/2007/02/01/how-to-launch-gui-applications-from-the-terminal/
open -a OneDrive

