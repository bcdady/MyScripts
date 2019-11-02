#!/usr/local/bin/python3
# ===================================== #
# NAME      : profile.py
# LANGUAGE  : Python
# VERSION   : 3
# AUTHOR    : Bryan Dady
# UPDATED   : 11/1/2019 - Convert from PowerShell Core
# INTRO     : python .profile script
# Created by New-Profile function of ProfilePal module
# ===================================== #

IsVerbose = False

 # Region: PowerShell Header
"""
    [CmdletBinding()]
    param ()
    #Set-StrictMode -Version latest

    # Uncomment the following 2 lines for testing profile scripts with Verbose output
    #'$VerbosePreference = ''Continue'''
    #$VerbosePreference = 'Continue'

    Write-Verbose -Message 'Detect -Verbose $VerbosePreference'
    switch ($VerbosePreference) {
        Stop             { $IsVerbose = $True }
        Inquire          { $IsVerbose = $True }
        Continue         { $IsVerbose = $True }
        SilentlyContinue { $IsVerbose = $False }
        Default          { if ('Verbose' -in $PSBoundParameters.Keys) {$IsVerbose = $True} else {$IsVerbose = $False} }
    }
    Write-Verbose -Message ('$VerbosePreference = ''{0}'' : $IsVerbose = ''{1}''' -f $VerbosePreference, $IsVerbose)

    # Region MyScriptInfo
        Write-Verbose -Message ('[{0}] Populating $MyScriptInfo' -f $MyInvocation.MyCommand.Name)
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
            Write-Verbose -Message 'Getting PSCallStack [$CallStack = Get-PSCallStack]'
            $CallStack      = Get-PSCallStack | Select-Object -First 1
            # $CallStack | Select Position, ScriptName, Command | format-list # FunctionName, ScriptLineNumber, Arguments, Location
            $myScriptName   = $CallStack.ScriptName
            $myCommand      = $CallStack.Command
            Write-Verbose -Message ('$ScriptName: {0}' -f $myScriptName)
            Write-Verbose -Message ('$Command: {0}' -f $myCommand)
            Write-Verbose -Message 'Assigning previously null MyCommand variables with CallStack values'
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
        Write-Verbose -Message ('[{0}] $MyScriptInfo populated' -f $MyInvocation.MyCommand.Name)

        # Cleanup
        foreach ($var in $properties.Keys) {
            Remove-Variable -Name ('My{0}' -f $var) -Force -ErrorAction SilentlyContinue
        }
        Remove-Variable -Name properties
        Remove-Variable -Name var

        if ($IsVerbose) {
            Write-Verbose -Message '$MyScriptInfo:'
            $Script:MyScriptInfo
        }
 """
    #End Region

# Region python header : import
import sys
import os
import argparse

# example: http://www.effbot.org/librarybook/sys/sys-argv-example-1.py
print("script name (path) is", sys.argv[0])

if len(sys.argv) > 1:
    print("there are", len(sys.argv)-1, "arguments:")
    for arg in sys.argv[1:]:
        print(arg)
else:
    print("there are no arguments!")

print('')
print(' # Loading python profile')
print('')

# capture starting path so we can go back after other things below might move around
#$startingPath = $PWD.Path

if IsVerbose:
    print('It''s VERBOSE!!')
else:
    print('NOT verbose, but hey -- no errors either :)')

exit()

""" print('Defining custom prompt')
function prompt {
    if (-not (Test-Path -Path Variable:\IsAdmin)) {
        # $IsWindows, if not already provided by pwsh $Host, is set in bootstrap.ps1
        if ($IsWindows) {
            $IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')
        } else {
            $IsAdmin = $False
        }
    }
    if ($IsAdmin) { $AdminPrompt = '[ADMIN]:' } else { $AdminPrompt = '' }
    if (Get-Variable -Name PSDebugContext -ValueOnly -ErrorAction SilentlyContinue) { $DebugPrompt = '[DEBUG]:' } else { $DebugPrompt = '' }
    if (Get-Variable -Name PSConsoleFile -ValueOnly -ErrorAction SilentlyContinue)  { $PSCPrompt = "[PSConsoleFile: $PSConsoleFile]" } else { $PSCPrompt = '' }
    if ($NestedPromptLevel -ge 1) { $PromptLevel = 'PS .\> >' } else { $PromptLevel = 'PS .\>' }

    return "[{0} @ {1}]`n{2}{3}{4}{5}" -f $Env:COMPUTERNAME, $PWD.Path, $AdminPrompt, $PSCPrompt, $DebugPrompt, $PromptLevel
}
if ($IsVerbose) {print(''})

#Region Bootstrap
    # Invoke Bootstrap.ps1, from the same root path as this $PROFILE script
    if (Get-Variable -Name 'myPS*' -ValueOnly -ErrorAction SilentlyContinue) {
        # python path variables have been initialized via a recent invocation of bootstrap.ps1
        print('')
        print('My python paths:')
        Get-Variable -Name 'myPS*' | Format-Table -AutoSize
    } else {
        # initialize variables, via bootstrap.ps1
        print ('(Test-Path -Path ./bootstrap.ps1): {0}' -f (Test-Path -Path ./Bootstrap.ps1))
        if (Test-Path -Path ./Bootstrap.ps1) {
            #print '. ./Bootstrap.ps1'
            . ./Bootstrap.ps1
        }

        if (Get-Variable -Name 'myPS*' -ValueOnly -ErrorAction SilentlyContinue) {
            # python path variables have been initialized via a recent invocation of bootstrap.ps1
            print('')
            print('My python paths:')
            Get-Variable -Name 'myPS*' | Format-Table -AutoSize
        } else {
            Write-Warning -Message './Bootstrap.ps1 may have encountered errors.'
        }
    }
#End Region

<# Yes! This even works in XenApp!
    & Invoke-Expression (New-Object Net.WebClient).DownloadString('http://bit.ly/e0Mw9w')
    # start-sleep -Seconds 3
#>
if (Get-Command -Name Set-ConsoleTitle -ErrorAction SilentlyContinue) {
    # Call Set-ConsoleTitle, from ProfilePal module
    if ($IsVerbose) {print(''})
    print(' # Set-ConsoleTitle >')
    Set-ConsoleTitle
    print(' # < Set-ConsoleTitle')
    if ($IsVerbose) {print(''})
}

# In case any intermediary scripts or module loads change our current directory, restore original path, before it's locked into the window title by Set-ConsoleTitle
Set-Location $startingPath

# Loading ProfilePal Module, and only if successful, call Set-ConsoleTitle to customize the ConsoleHost window title
Import-Module -Name ProfilePal
if ($?) {
    # Call Set-ConsoleTitle function from ProfilePal module
    Set-ConsoleTitle
}
function Initialize-MyScript {
    [cmdletbinding()]
    param(
      # Specifies a path to a script to be run
        [Parameter(Mandatory,
            Position=0,
            ParameterSetName="ParameterSetName",
            ValueFromPipeline,
            ValueFromPipelineByPropertyName,
            HelpMessage="Path to one or more locations.")]
        [Alias("PSPath")]
        [ValidateNotNullOrEmpty()]
        [string[]]
        $Path
    )

    # Begin block of Advanced Function
    Begin {
        if (Test-Path -Path $Path -PathType Leaf) {
            # confirmed path is ok, proceed
            $ScriptPath = $Path
        } else {
            # $Path not found, if OS $IsWindows, try \WindowsPowerShell\ instead of \PowerShell\
            if ($IsWindows) {
                if (Test-Path -Path ($Path -replace '\\python\\','\WindowsPowerShell\') -PathType Leaf) {
                    # confirmed path is ok, proceed
                    print ('Test-Path failed for ''{0}'', but a script with the same name was found at {1} ' -f $Path, $ScriptPath) -Verbose
                    $ScriptPath = ($Path -replace '\\PowerShell\\','\WindowsPowerShell\')
                } else {
                    throw "\tError: Test-Path failed. $Path not found"
                }
            } else {
                throw "\tError: Test-Path failed. $Path not found"
            }
        }
        $ScriptName = Split-Path -Path $ScriptPath -Leaf
    } # End of Begin block

    # Process block of Advanced Function
    Process {
      print (' # Initializing {0} #' -f $ScriptName)
      print (' . {0}' -f $ScriptPath)
      # dot-source script file containing Merge-MyPSFiles and related functions
      . $ScriptPath

    } # End of Process block

    # End block of Advanced Function
    End { } # End of End block

  }

print ('$HostOS = ''{0}''' -f $HostOS)
# Detect host OS and then jump to the OS specific profile sub-script
if ($IsLinux) {
    $Private:SubProfile = (Join-Path -Path (split-path -Path $MyScriptInfo.CommandPath) -ChildPath 'Microsoft.PowerShell_profile-Linux.ps1')
}

if ($IsMacOS) {
    $Private:SubProfile = (Join-Path -Path (split-path -Path $MyScriptInfo.CommandPath) -ChildPath 'Microsoft.PowerShell_profile-macOS.ps1')
}

if ($IsWindows) {
    $Private:SubProfile = (Join-Path -Path (split-path -Path $MyScriptInfo.CommandPath) -ChildPath 'Microsoft.PowerShell_profile-Windows.ps1')
}

if ($IsVerbose) {print ''}
print ('$SubProfile = ''{0}''' -f $Private:SubProfile)

# Load/invoke OS specific profile sub-script
if (Test-Path -Path $SubProfile) {
    # dot-source it
    . $SubProfile
} else {
    throw ('Failed to locate OS specific profile sub-script: {0}' -f $SubProfile)
}
Remove-Variable -Name SubProfile -Force

# Here's an example of how convenient aliases can be added to your PS profile
New-Alias -Name rdp -Value Start-RemoteDesktop -ErrorAction Ignore

print ''
print ' ** To view additional available modules, run: Get-Module -ListAvailable'
print ' ** To view cmdlets available in a given module, run: Get-Command -Module <ModuleName>'

# Do you like easter eggs?:
#& iex (New-Object Net.WebClient).DownloadString('http://bit.ly/e0Mw9w')

if ($IsVerbose) {print ''}
print ' # End of python $Profile CurrentUserCurrentHost #'

# For intra-profile/bootstrap script flow testing
if ($IsVerbose) {
    print 'Start-Sleep -Seconds 3'
    Start-Sleep -Seconds 3
}
 """