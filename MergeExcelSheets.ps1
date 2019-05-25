#---------------------------------------------------------------------------------
#The sample scripts are not supported under any Microsoft standard support
#program or service. The sample scripts are provided AS IS without warranty
#of any kind. Microsoft further disclaims all implied warranties including,
#without limitation, any implied warranties of merchantability or of fitness for
#a particular purpose. The entire risk arising out of the use or performance of
#the sample scripts and documentation remains with you. In no event shall
#Microsoft, its authors, or anyone else involved in the creation, production, or
#delivery of the scripts be liable for any damages whatsoever (including,
#without limitation, damages for loss of business profits, business interruption,
#loss of business information, or other pecuniary loss) arising out of the use
#of or inability to use the sample scripts or documentation, even if Microsoft
#has been advised of the possibility of such damages
#---------------------------------------------------------------------------------

#requires -version 2.0

Param(
    [String]$Path
)

If (Test-Path -Path $Path) {

    #Launch Excel, and make it do as its told (supress confirmations)
    $Excel = New-Object -ComObject Excel.Application
    $Excel.Visible = $True
    $Excel.DisplayAlerts = $False

    $WorkBook = $Excel.Workbooks.Open("$Path")

    # Get a new sheet/tab in the source workbook
    $NewWorkSheet = $Excel.ActiveWorkbook.Worksheets.Add()
    $Row = 2
    $WorkBook.Sheets | ForEach-Object {

        "Sheet: $($PSItem.Name) ; Row: $Row" # : UsedRange $($PSItem.UsedRange)"
        #Loop through sheets/tabs, selecting/copying the specified range. Then find next available row on the destination worksheet and paste the data

        # If(($NewWorkSheet.ActiveSheet.UsedRange.Count -eq 1) -and ([String]::IsNullOrEmpty($NewWorkSheet.ActiveSheet.Range("A1").Value2))){
        #     #If there is only 1 used cell and it is blank select A1
        #     [void]$WorkBook.ActiveSheet.Range("A1","F$(($WorkBook.ActiveSheet.UsedRange.Rows | Select-Object -Last 1).Row)").Copy()
        #     [void]$NewWorkSheet.Activate()
        #     [void]$NewWorkSheet.ActiveSheet.Range("A1").Select()
        # } else { #If there is data go to the next empty row and select Column A
        # [void]$WorkBook.ActiveSheet.Range("A2","F$(($WorkBook.ActiveSheet.UsedRange.Rows | Select-Object -Last 1).Row)").Copy()

        [void]$PSItem.Activate()
        [void]$WorkBook.ActiveSheet.Range("A7","V101").Copy()
        #[void]$WorkBook.ActiveSheet.Range("A7","V$(($WorkBook.ActiveSheet.UsedRange.Rows | Select-Object -Last 1).Row)").Copy()

        [void]$NewWorkSheet.Activate()
        [void]$NewWorkSheet.Range("A$Row").Select()
        # [void]$NewWorkSheet.Range("A$(($NewWorkSheet.UsedRange.Rows | Select-Object -Last 1).row+1)").Select()
        # }
        [void]$NewWorkSheet.Paste()
        $Row += 102
        Start-Sleep -Seconds 1
    }
}

#$NewWorkSheet.Save()
#$NewWorkSheet.Close()

#release the COM object
#$WorkBook.Close()
#$Excel.Quit()
