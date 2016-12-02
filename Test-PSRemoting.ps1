<#
.SYNOPSIS
Check remote target computers for PowerShell remoting capabilities.
Uses runspaces for concurrency.

Copyright (C) 2015, Svendsen Tech
All rights reserved.
Author: Joakim Borger Svendsen

.EXAMPLE
    .\Test-PSRemoting.ps1 -ComputerName $Servers -Credential $mycred
.EXAMPLE
    .\Test-PSRemoting.ps1 -ComputerName $Servers | Format-Table -AutoSize
.EXAMPLE
    $Results = .\Test-PSRemoting.ps1 -ComputerName $Servers

.LINK
    http://www.powershelladmin.com/wiki/Test_PowerShell_Remoting_Cmdlet
#>

[CmdletBinding()]
param(
    # Target computer names.
    [Parameter(ValueFromPipeline=$true,
               ValueFromPipelineByPropertyName=$true,
               Mandatory=$true)][Alias('Cn', 'Hostname', 'PSComputerName')]
        [string[]] $ComputerName,
        # Prompt for credentials to be used when connecting.
        [switch] $PromptForCredentials,
        # Supply PSCredentials object to be used when connecting.
        [System.Management.Automation.Credential()] $Credential = [System.Management.Automation.PSCredential]::Empty,
        # Number of simultaneously running threads.
        [int] $ThrottleLimit = 32,
        # Do not display progress using Write-Progress.
        [switch] $HideProgress,
        # Timeout in seconds.
        [int] $Timeout = 30,
        # Don't display end summary showing start and end time using Write-Host.
        [switch] $Quiet
)

begin {
    $MyEAP = 'Stop'
    $ErrorActionPreference = $MyEAP
    $StartTime = Get-Date
    if ($PromptForCredentials) {
        $Credential = Get-Credential
    }
    $RunspaceTimers = [HashTable]::Synchronized(@{})
    $Runspaces = New-Object -TypeName System.Collections.ArrayList
    $RunspaceCounter = 0
    Write-Verbose -Message 'Creating initial session state.'
    $ISS = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
    $ISS.Variables.Add((New-Object -TypeName System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList 'RunspaceTimers', (Get-Variable -Name 'RunspaceTimers' -ValueOnly), ''))
    Write-Verbose -Message 'Creating runspace pool.'
    $RunspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(1, $ThrottleLimit, $ISS, $Host)
    $RunspacePool.ApartmentState = 'STA'
    $RunspacePool.Open()
    # This is the script block that is run for each computer.
    $ScriptBlock = {
        [CmdletBinding()]
        param(
            [string] $Computer,
            [int] $ID,
            $Credential
        )
        # Get the start time.
        $RunspaceTimers.$ID = Get-Date
        # The objects returned here are passed to the host...
        if (-not (Test-Connection $Computer -Count 1 -Quiet)) {
            New-Object psobject -Property @{
                ComputerName = $Computer
                Success = $null
                Error   = 'No ping reply'
            }
            continue
        }
        $IcmHash = @{
            ErrorAction = 'Stop'
            ComputerName = $Computer
            ScriptBlock = { 'It works' }
        }
        if ($Credential.Username -ne $null) {
            $IcmHash.Credential = $Credential
        }
        try {
            $Result = Invoke-Command @IcmHash
        }
        catch {
            New-Object psobject -Property @{
                ComputerName = $Computer
                Success = $null
                Error = $_
            }
            continue
        }
        # Check if results are as expected.
        if ($Result -ne 'It works') {
            New-Object psobject -Property @{
                ComputerName = $Computer
                Success = $null
                Error = 'Unknown error'
            }
            continue
        }
        # Everything went well, return success object.
        New-Object psobject -Property @{
            ComputerName = $Computer
            Success = $true
            Error = $null
        }
    } # end of script block
    
    function Get-PSRemotingResult {
        [CmdletBinding()]
        param( [switch]$Wait )
        do
        {
            $More = $false
            foreach ($Runspace in $Runspaces) {
                $StartTime = $RunspaceTimers[$Runspace.ID]
                if ($Runspace.Handle.IsCompleted)
                {
                    Write-Verbose -Message ('Thread done for {0}' -f $Runspace.IObject)
                    $Runspace.PowerShell.EndInvoke($Runspace.Handle)
                    $Runspace.PowerShell.Dispose()
                    $Runspace.PowerShell = $null
                    $Runspace.Handle = $null
                }
                elseif ($Runspace.Handle -ne $null) {
                    $More = $true
                }
                if ($Timeout -and $StartTime) {
                    if ((New-TimeSpan -Start $StartTime).TotalSeconds -ge $Timeout -and $Runspace.PowerShell) {
                        Write-Warning -Message ('Timeout {0}' -f $Runspace.IObject)
                        $Runspace.PowerShell.Dispose()
                        $Runspace.PowerShell = $null
                        $Runspace.Handle = $null
                    }
                }
            }
            if ($More -and $PSBoundParameters['Wait']) {
                Start-Sleep -Milliseconds 100
            }
            foreach ($Thread in $Runspaces.Clone()) {
                if (-not $Thread.Handle) {
                    Write-Verbose -Message ('Removing {0} from runspaces' -f $Thread.IObject)
                    $Runspaces.Remove($Thread)
                }
            }
            if (-not $HideProgress) {
                $ProgressSplatting = @{
                    Activity = 'Testing PSRemoting capabilities'
                    Status = 'Processing: {0} of {1} total threads done' -f ($RunspaceCounter - $Runspaces.Count), $RunspaceCounter
                    PercentComplete = ($RunspaceCounter - $Runspaces.Count) / $RunspaceCounter * 100
                }
                Write-Progress @ProgressSplatting
            }
        }
        while ($More -and $PSBoundParameters['Wait'])
    } # end of Get-PSRemotingResult
} # end of begin block

process {
    foreach ($Computer in $ComputerName) {
        $RunspaceCounter++
        $psCMD = [System.Management.Automation.PowerShell]::Create().AddScript($ScriptBlock)
        [void] $psCMD.AddParameter('ID', $RunspaceCounter)
        [void] $psCMD.AddParameter('Computer', $Computer)
        [void] $psCMD.AddParameter('Credential', $Credential)
        [void] $psCMD.AddParameter('Verbose', $VerbosePreference)
        $psCMD.RunspacePool = $RunspacePool
        Write-Verbose -Message "Testing PSRemoting capabilities: Checking $Computer"
        [void]$Runspaces.Add(@{
            Handle = $psCMD.BeginInvoke()
            PowerShell = $psCMD
            IObject = $Computer
            ID = $RunspaceCounter
        })
        Get-PSRemotingResult
    }
}

end {
    Get-PSRemotingResult -Wait
    if (-not $HideProgress) {
        Write-Progress -Activity 'Testing PSRemoting capabilities' -Status 'Done' -Completed
    }
    Write-Verbose -Message 'Closing runspace pool.'
    $RunspacePool.Close()
    $RunspacePool.Dispose()
    if (-not $Quiet) {
        Write-Host -ForegroundColor Green ('Start time: ' + $StartTime)
        Write-Host -ForegroundColor Green ('End time:   ' + (Get-Date))
    }
}
