
# # # # # # # # # # # # # # # # # # # # #
# Credit: http://powershell.com/cs/blogs/tips/archive/2009/12/17/get-process-owners.aspx
function Get-MyProcess {
    [cmdletbinding()]
    param (
         [string]
         $ProcessName = '',

         [string]
         $UserName = $env:USERNAME,

         [switch]
         $Get_Process
     )

    if ($null -eq $ProcessName) {
        $MyProcess = Get-WmiObject Win32_Process
    } else {
        $MyProcess = Get-WmiObject Win32_Process -Filter "name='$ProcessName'"
    }
    
    Write-Debug -Message "MyProcess Length: $($MyProcess.Length)"
    
    $MyProcess | foreach {
        Write-Debug -Message "Add-Member Length: $($PSItem.GetOwner().User)"
        Add-Member -MemberType NoteProperty -Name Owner -Value ($PSItem.GetOwner().User) -InputObject $PSItem -PassThru
    } |
        Where-Object -FilterScript {$PSItem.Owner -eq "$UserName"} | 
            Select-Object -Property Name, Owner, ProcessId, PSComputerName, SessionId
            # Format-Table -Property Name, Owner, ProcessId, PSComputerName, SessionId -AutoSize

    if ($Get_Process) {
        # pipe WMI object back into Get-Process cmdlet, for standard output
        return (Get-Process -Id ($MyProcess.ProcessId))
    } else {
        return $MyProcess
    }
}

function Stop-MyProcess {
    [cmdletbinding()]
    param
     (
         [string]
         $ProcessName = 'iexplore.exe',

         [string]
         $UserName = $env:USERNAME,

         [switch]
         $Confirm
     )

    $p = Get-MyProcess 
    <# Get-WmiObject Win32_Process -Filter "name='$ProcessName'" |
        foreach {
            Add-Member -MemberType NoteProperty -Name Owner -Value ($PSItem.GetOwner().User) -InputObject $PSItem -PassThru
        } |
            Where-Object -FilterScript {$PSItem.Owner -eq "$UserName"}
    #>
    if ($Confirm) {
        return Stop-Process -Id ($p.ProcessId) -Confirm -PassThru
    } else {
        return Stop-Process -Id ($p.ProcessId) -PassThru
    }
}