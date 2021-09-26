#!/usr/bin/env pwsh
#Requires -Version 6
#========================================
# NAME      : Microsoft.PowerShell_profile-macOS.ps1
# LANGUAGE  : Microsoft PowerShell Core
# AUTHOR    : Bryan Dady
# UPDATED   : 12/10/2018
# COMMENT   : Personal PowerShell Profile script, specific to running on a macOS host
#========================================
[CmdletBinding()]
param ()
Set-StrictMode -Version latest

# Uncomment the following 2 lines for testing profile scripts with Verbose output
#'$VerbosePreference = ''Continue'''
#$VerbosePreference = 'Continue'

Get-IsVerbose

# Region MyScriptInfo
# Only call (and use results from Get-MyScriptInfo function, if it was loaded from ./Bootstrap.ps1)
if (Test-Path -Path Function:\Get-MyScriptInfo) {
    $MyScriptInfo = Get-MyScriptInfo($MyInvocation) -Verbose

    if ($IsVerbose) { $MyScriptInfo }    
}
#End Region

Write-Output -InputObject ' # Loading PowerShell macOS Profile Script #'
Write-Verbose -Message (' ... from {0} # ' -f $MyScriptInfo.CommandPath)

$PSDefaultParameterValues = @{
    'Format-Table:autosize' = $true
    'Format-Table:wrap'     = $true
    'Get-Help:Examples'     = $true
    'Get-Help:Online'       = $true
    'Enter-PSSession:Credential'          = {Get-Variable -Name my2acct -ErrorAction Ignore}
    'Enter-PSSession:EnableNetworkAccess' = $true
    'New-PSSession:Credential'            = {Get-Variable -Name my2acct -ErrorAction Ignore}
    'New-PSSession:EnableNetworkAccess'   = $true
}

# Bootstrap likely set this, but since we're inside a macOS specific profile script ...
$PathSplitChar = ':'

# Customize PATH and other environment variables

# ensure aws-cli path is in PATH
# included in .oh-my-zsh/custom/path
# $Env:AWSPATH=~/Library/Python/3.7/bin

# ensure go path is defined, and also add GOPATH/bin in PATH
# included in .oh-my-zsh/custom/path
$Env:GOPATH=('{0}/go' -f $HOME)
$GOBIN=('{0}/bin' -f $Env:GOPATH)

# ensure PYTHONPATH is in PATH
# included in .oh-my-zsh/custom/path
# $PYTHONPATH="$HOME/Library/Python/3.7/lib/python/site-packages/:$HOME/Library/Python/3.8/lib/python/site-packages/:/usr/local/lib/python3.7/site-packages:/usr/local/lib/python3.8/site-packages"

# ensure pylint path is in PATH
# included in .oh-my-zsh/custom/path
# $PY3PATH = Join-Path -Path (Get-ChildItem -Path $HOME/Library/Python/3.* | Select-Object -Last 1 -Property FullName).FullName -ChildPath 'bin'

# add $HOME/bin to PATH, for kubectl-eks (and aws-iam-authenticator?)
#:/usr/local/Cellar/gettext/0.20.1/bin/gettext
# export PATH=$PYTHONPATH:$PATH
$Env:PATH = ($Env:AWSPATH, $GOBIN, $PY3PATH, $Env:PYTHONPATH, $Env:PATH) -join $PathSplitChar

Write-Verbose -Message ' ... checking status of PSGallery ...'
# Check PSRepository status
#$PSGallery = Get-PSRepository -Name PSGallery | Select-Object -Property Name,InstallationPolicy
if ((Get-PSRepository -Name PSGallery | Select-Object -Property Name,InstallationPolicy).InstallationPolicy -ne 'Trusted') {
  Write-Output -InputObject '# Trusting PSGallery Repository #'
  Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
} else {
  Get-PSRepository | Select-Object -Property Name,InstallationPolicy | Format-Table
}
#Remove-Variable -Name PSGallery

Write-Debug -Message (' # # # $VerbosePreference: {0} # # #' -f $VerbosePreference)
Write-Verbose -Message 'Checking that .\scripts\ folder is available'

# if ($variable:myPSScriptsPath) {
#     Write-Verbose -Message ('Loading scripts from {0} ...' -f $myPSScriptsPath)
#     Write-Output -InputObject ''

#     $LoadScript = Join-Path -Path $myPSScriptsPath -ChildPath 'Set-ConsoleTheme.ps1'
#     if (Test-Path -Path $LoadScript) {
#     Write-Verbose -Message 'Initializing Set-ConsoleTheme.ps1'
#         Initialize-MyScript -Path $LoadScript
#         if (Get-Command -Name Set-ConsoleTheme) {
#     Write-Verbose -Message 'Set-ConsoleTheme'
#     Set-ConsoleTheme
#     } else {
#             Write-Warning -Message 'Failed to get command Set-ConsoleTheme'
#     }

#     } else {
#         Write-Warning -Message ('Failed to initialize (dot-source) {0}' -f $LoadScript)
#     }
# } else {
#     Write-Warning -Message ('Failed to locate Scripts folder {0}; run any scripts.' -f $myPSScriptsPath)
# }

Write-Verbose -Message 'Declaring function Save-Credential'
function Save-Credential {
    [cmdletbinding(SupportsShouldProcess)]
    Param(
        [Parameter(Position = 0)]
        [string]
        $Variable = 'privileged',
        [Parameter(Position = 1)]
        [string]
        $USERNAME = $(if ($IsWindows) {$Env:USERNAME} else {$Env:USER})
    )

    $SaveCredential = $false
    Write-Verbose -Message 'Starting Save-Credential'
    $VarValueSet = [bool](Get-Variable -Name $Variable -ValueOnly -ErrorAction SilentlyContinue)
    Write-Verbose -Message ('$VarValueSet = ''{0}''' -f $VarValueSet)
    if ($VarValueSet) {
        Write-Warning -Message ('Variable ''{0}'' is already defined' -f $Variable)
        if ((read-host -prompt ('Would you like to update/replace the credential stored in {0}`? [y]|n' -f $Variable)) -ne 'y') {
            Write-Warning -Message 'Ok. Aborting Save-Credential.'
        }
    } else {
        $SaveCredential = $true
    }

    Write-Verbose -Message ('$SaveCredential = {0}' -f $SaveCredential)
    if ($SaveCredential) {

        Write-Output -InputObject ''
        Write-Output -InputObject ' # Prompting to capture elevated credentials. #'
        Write-Output -InputObject ' ...'
        Set-Variable -Name $Variable -Value $(Get-Credential -UserName $USERNAME -Message 'Store privileged credentials for convenient use later.') -Scope Global -Description 'Stored privileged credentials for convenient re-use.'
        if ($?) {
            Write-Output -InputObject ('Elevated credentials stored in variable: {0}.' -f $Variable)
        }
    }
} # end Save-Credential

New-Alias -Name rename -Value Rename-Item -ErrorAction SilentlyContinue

Write-Output -InputObject ''

if (Get-Command -Name Backup-Logs -ErrorAction SilentlyContinue) {
    # Backup local PowerShell log files
    Write-Output -InputObject 'Archive PowerShell logs'
    Backup-Logs
}

Write-Output -InputObject ' # End of PowerShell macOS Profile Script #'

    # For intra-profile/bootstrap script flow Testing
if ($IsVerbose) {
    Write-Output -InputObject 'Verbose testing: pausing before proceeding'
    Start-Sleep -Seconds 3
}

Import-Module -Name posh-git -PassThru

# Configure AWS profile, region
#if ($null -eq $(Get-Variable -Name StoredAWSCredentials -ErrorAction SilentlyContinue)) {
    Set-AWSCredential -ProfileName $((Get-AWSCredential -ListProfile)[0]) -Verbose
#}
#if ($null -eq $(Get-Variable -Name StoredAWSRegion -ErrorAction SilentlyContinue)) {
    Set-DefaultAWSRegion -Region us-west-2 -Verbose
#}


# https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_prompts
if ($IsVerbose) {Write-Output -InputObject ''}
Write-Verbose -Message 'Defining custom prompt'
function prompt {

    Write-Verbose -Message 'Entered prompt function'

    # $IsWindows, if not already provided by $Host (in recent pwsh releases), it's set in bootstrap.ps1
    if ($IsWindows) {
        if (-not (Get-Variable -Name IsAdmin -ValueOnly -ErrorAction SilentlyContinue)) {
            $IsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator')
            if ($IsAdmin) { $AdminPrompt = '[ADMIN]:' } else { $AdminPrompt = '' }
        }
    } else {
        if (-not (Get-Variable -Name IsRoot -ValueOnly -ErrorAction Ignore)) {
            $IsRoot = ($ENV:USER -eq 'root')
            if ($IsRoot) { $AdminPrompt = '[root]:' } else { $AdminPrompt = '' }
        }
        if ($(hostname) -eq 'Bryan-Dady--MacBook-Pro') { $hostname = 'BCD-MBP' } else { $hostname = $(hostname)}
    }

    Write-Verbose -Message 'Determined hostname and AdminPrompt'
    Write-Verbose -Message 'Detecting AWS config'

    # $realLASTEXITCODE = $LASTEXITCODE
    $AWSprompt = "_no_aws_profile_"
    Try {
        if ($null -ne $(Get-Variable -Name StoredAWSCredentials)) {
            $AWSprompt = "AWS Profile: "
            $AWSprompt += "$StoredAWSCredentials"
            if (!$AWSprompt.EndsWith("@")) { $AWSprompt += "@" }
        }
        if ($null -ne $(Get-Variable -Name StoredAWSRegion)) {
            $AWSprompt += "$StoredAWSRegion" }
        $AWSprompt += " "
    }
    Catch {
        $AWSprompt = ">no-aws-profile<"
    }

    $PSVer = ('PS {0}.{1}' -f $PSVersionTable.PSVersion.Major, $PSVersionTable.PSVersion.Minor)

    if (Get-Variable -Name PSDebugContext -ValueOnly -ErrorAction SilentlyContinue) { $DebugPrompt = '[DEBUG]:' } else { $DebugPrompt = '' }
    if (Get-Variable -Name PSConsoleFile -ValueOnly -ErrorAction SilentlyContinue)  { $PSCPrompt = "[PSConsoleFile: $PSConsoleFile]" } else { $PSCPrompt = '' }
    if ($NestedPromptLevel -ge 1) { $PromptLevel = ('{0} >>_ ' -f $PSVer) } else { $PromptLevel = ('{0} >_ ' -f $PSVer) }

    $prompt = "[{0}] " -f $hostname
    $prompt += & $GitPromptScriptBlock
    $prompt += ("`n{0}{1}{2}{3}{4}" -f $AWSPrompt, $AdminPrompt, $PSCPrompt, $DebugPrompt, $PromptLevel)
    return $prompt
}
if ($IsVerbose) {Write-Output -InputObject ''}
