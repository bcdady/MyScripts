#!/usr/local/bin/pwsh
#Requires -Version 3
[CmdletBinding()]
param()

Write-Verbose -Message 'Declaring function Get-GPComputerRSoP'

function Get-GPComputerRSoP {
    [CmdletBinding()]
    param (
        # Specifies the output file format
        [Parameter(Position=0)]
        [ValidateSet('HTML','XML')]
        [string[]]
        $ReportType = 'XML',
        # Specifies a path for the output file
        [Parameter(Position=1)]
        [ValidateScript({Test-Path -Path $PSItem -PathType Leaf -IsValid})]
        [Alias('PSPath')]
        [string[]]
        $Path = (Join-Path -Path $Env:TEMP -ChildPath ('GPResult.{0}' -f $ReportType)),
        [Parameter(Position=2)]
        [string[]]
        $ComputerName = '.'
    )
    
    # Initialize Variables
    $OutputFile = $Path

    # Instantiate the GPMgmt.GPM object.
    $GPM = New-Object -ComObject GPMgmt.GPM

    # Next step is to obtain all constants and save it in a variable.
    $constants = $gpm.GetConstants()

    # Now create reference RSOP object using required constants.
    $gpmRSOP = $GPM.GetRSOP($Constants.RSOPModeLogging,$null,0)

    $gpmRSOP.LoggingComputer = $Env:COMPUTERNAME
    $gpmRSOP.LoggingUser     = $Env:USERNAME
    # To collect RSoP for the Computer only (skip User context GP data), we use the “RsopLoggingNoUser” constant value (instead of $gpmRSOP.LoggingUser).
    $gpmRSOP.LoggingFlags = $Constants.RsopLoggingNoUser

    # Invoke the query
    $gpmRSOP.CreateQueryResults()

    # To export data to a output file below command is used.
    switch ($ReportType) {
        'HTML' { 
            $GenerateReport = $gpmRSOP.GenerateReportToFile($constants.ReportHTML,$OutputFile)
        }
        Default {
        # 'XML' { 
            $GenerateReport = $gpmRSOP.GenerateReportToFile($constants.ReportXML,$OutputFile)
        }
    }

    return $GenerateReport

    <#
        .SYNOPSIS
            Get (Windows) Group Policy - Resultant Set of Policy for the local, or specified remote computer.\

        .DESCRIPTION
            Get (Windows) Group Policy - Resultant Set of Policy for the local, or specified remote computer.
            There are generally two methods to get "Resultant Set of [Group] Policy", both require the User (account) executing the command has logged-in once at-least in the computer.

            To overcome this condition issues, Get-GPComputerRSoP directly access Group Policy Management COM Object (which is also used by gpresult.exe and Get-GPResultantSetOfPolicy commandlet.

        .EXAMPLE
            PS .\> Get-GPComputerRSoP
            Outputs the Resultant Set of Policy (RSoP) information for the local computer to an XML file (in $Env:Temp)

        .EXAMPLE
            PS .\> Get-GPComputerRSoP -ReportType HTML -Path $Env:USERPROFILE\Desktop\GPComputerRSoP.htm -ComputerName COMPUTER-02
            Outputs the Resultant Set of Policy (RSoP) information for the remote computer (COMPUTER-02) to an HTM file on the user's desktop

        .OUTPUTS
            Resultant Set of Policy report file, in either HTML or XML format
        .NOTES
            https://blogs.technet.microsoft.com/meamcs/2015/09/24/powershell-retrieve-group-policy-details-for-remote-computer/
            Using Method 1 and Method 2, even if we want the group policy information only for the computer irrespective of user, it is not possible without the user logged in at-least once as the command retrieves resulting set of policies that are enforced for specified user on the target computer. 
    #>
}

<#
    UpGuard snippet:

    $GPM = New-Object -ComObject GPMgmt.GPM
    $Constants = $gpm.GetConstants()
    $gpmRSOP = $GPM.GetRSOP($Constants.RSOPModeLogging,$null,0)
    $gpmRSOP.LoggingComputer = $Env:COMPUTERNAME
    $gpmRSOP.LoggingUser = $Env:USERNAME
    $gpmRSOP.LoggingFlags = $Constants.RsopLoggingNoUser
    $gpmRSOP.CreateQueryResults()
    $ReportFile = $gpmRSOP.GenerateReportToFile($constants.ReportXML,(Join-Path -Path $Env:TEMP -ChildPath 'GPResult.xml'))
    return ((Get-Content -Path $($ReportFile.Result)) -as [xml])
#>