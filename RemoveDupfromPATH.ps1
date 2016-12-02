# --------------------------------------- 
# The sample scripts are not supported under any Microsoft standard support program or service. The sample scripts are provided AS IS without warranty of any kind. Microsoft further disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose. The entire risk arising out of the use or performance of the sample scripts and documentation remains with you. In no event shall  Microsoft, its authors, or anyone else involved in the creation, production, or delivery of the scripts be liable for any damages whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use  of or inability to use the sample scripts or documentation, even if Microsoft has been advised of the possibility of such damages 
# --------------------------------------- 

$RegKey = ([Microsoft.Win32.Registry]::LocalMachine).OpenSubKey("SYSTEM\CurrentControlSet\Control\Session Manager\Environment", $True)
$PathValue = $RegKey.GetValue("Path", $Null, "DoNotExpandEnvironmentNames")
Write-host "Original path :" + $PathValue 
$PathValues = $PathValue.Split(";", [System.StringSplitOptions]::RemoveEmptyEntries)
$IsDuplicate = $False
$NewValues = @()
 
ForEach ($Value in $PathValues)
{
    if ($NewValues -notcontains $Value)
    {
        $NewValues += $Value
    }
    else
    {
        $IsDuplicate = $True
    }
}
 
if ($IsDuplicate)
{
    $NewValue = $NewValues -join ";"
    $RegKey.SetValue("Path", $NewValue, [Microsoft.Win32.RegistryValueKind]::ExpandString)
    Write-Host "Duplicate PATH entry found and new PATH built removing all duplicates. New Path :" + $NewValue
}
else
{
    Write-Host "No Duplicate PATH entries found. The PATH will remain the same."
}
 
$RegKey.Close()
