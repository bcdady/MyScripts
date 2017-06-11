:: ################# ABOUT ##########################
:ABOUT
@ECHO OFF
REM SET scriptname=Profile-Sync.cmd
::  Comments: Profile-Sync.cmd can live anywhere, although it expects local environment variables from a windows logged on session to function properly.
::  Synchronizes primary (H:), admin ("2" account;  documents and favorites only), and local user profile folders
::  Created by Bryan Dady
::  bryan@dady.us
::  Last Modified - 2014/06/02
REM SET scriptver=Version 1.0
::  History: Presumes robocopy.exe is available in the environment variables
::
:: ################# HEADER #########################
:HEADER
REM @ECHO %scriptname%
@ECHO Starting %0 %date% %time%
REM @Echo %scriptver%

:: ################# SETUP ##########################
:: Test HOMESHARE
If exist %HOMESHARE% then echo Profile1 is %HOMESHARE%
else (ECHO Could not confirm source path of user's home directory)

:: Setup admin '2 account' HOMESHARE path string
SET HOMESHARE-2 %HOMESHARE%2
echo Profile1 is %HOMESHARE-2%

echo local profile is %USERPROFILE%
REM We look good to go, so let's jump to MAIN
IF EXIST %USERPROFILE% GOTO MAIN:

REM SET ProfileLocal = %USERPROFILE% :: No need to redefine an existing variable
:: Unless all setup steps succeeeded - in which case jumped to :MAIN, we fail out here
GOTO FAIL
::  ################# MAIN ##########################
:MAIN
@ECHO.

REM ECHO ErrorLevel: %errorlevel% :: DEBUG
:END