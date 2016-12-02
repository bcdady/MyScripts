#requires -Version 2

# PowerShell function to list Start Menu Shortcuts
# http://www.computerperformance.co.uk/powershell/powershell_function_shortcut.htm#Putting_it_all_together_-_List_Shortcuts_and_Targets
Function Get-StartMenu
{
    Begin{
        Clear-Host
        $Path = "$Env:ProgramData\Microsoft\Windows\Start Menu\Programs"
        $x = 0
    } # End of Begin
    Process {
        $StartMenu = Get-ChildItem $Path -Recurse -Include *.lnk
        ForEach($ShortCut in $StartMenu) 
        {
            $Shell = New-Object -ComObject WScript.Shell 
            $Properties = @{
                ShortcutName = $ShortCut.Name
                LinkTarget   = $Shell.CreateShortcut($ShortCut).targetpath
            }
            New-Object -TypeName PSObject -Property $Properties 
            $x ++
        } #End of ForEach
        $null = [Runtime.InteropServices.Marshal]::ReleaseComObject($Shell)
    } # End of Process
    End{
        "`nStart Menu items = $x "
    }
} 
#Example of function in action:

Get-StartMenu |
Sort-Object -Property ShortcutName |
Format-Table -Property ShortcutName, LinkTarget -AutoSize