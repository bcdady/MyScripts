$ErrorActionPreference = 'Inquire'
function Get-Shortcut {
<#
    .SYNOPSIS
        Enumerate shortcut files and their attributes, from specified folder(s)
    .DESCRIPTION
        Expects path to a directory/folder, and returns shortcut file objects for al *.lnk files
    .PARAMETER $path
        $path specifies the directory or folder to be enumerated
    .EXAMPLE
        PS .\>Get-Shortcut $env:UserProfile\Desktop

        Link         : Shortcut.lnk
        TargetPath   : $env:UserProfile\Downloads\sample_document.pdf
        WindowStyle  : 1
        IconLocation : ,0
        Hotkey       : 
        Target       : sample_document.pdf
        Arguments    : 
        LinkPath     : $env:UserProfile\Desktop\Shortcut.lnk

    .EXAMPLE
        PS .\>Get-Shortcut $env:UserProfile\Desktop | select-object -Property Link, Target, Arguments;

        Link                                             Target                                          Arguments
        ----                                             ------                                          ---------
        Gartner Toolkit - how to document.lnk            toolkit_how_to_document_your_239747.zip    
        Git Shell.lnk                                    GitHub.appref-ms                                --open-shell   
        GoToMeeting.lnk                                  g2mstart.exe                                    "/Action Host" "/Trigger Shortcut" "/

    .NOTES
        NAME        :  Get-Shortcut
        VERSION     :  1.0.0.0   
        LAST UPDATED:  11/1/2015
        AUTHOR      :  @bcdady
#>
  param(
        [Parameter(Mandatory = $false,
            Position = 0,
            ValueFromPipeline = $true,
            HelpMessage = 'Folder path to look for .lnk shortcuts'
        )]
        [ValidateScript({Test-Path -Path $PSItem})]
        [string]
        $path = "$Env:ProgramData\Microsoft\Windows\Start Menu\Programs" # $(Join-Path -Path $env:UserProfile -ChildPath 'Desktop')
  )

  $obj = New-Object -ComObject WScript.Shell

<#  if ($path -eq $null) {
    $pathUser = [System.Environment]::GetFolderPath('Desktop')
    # $pathCommon = $obj.SpecialFolders.Item('AllUsersStartMenu')
    $path = Get-ChildItem $pathUser, $pathCommon -Filter *.lnk -Recurse 
  }
#>

Get-ChildItem $path -Filter *.lnk | ForEach-Object -Process {
    Write-Output -InputObject "debug: Getting SC info for $($PSItem.FullName)"
      $link = $obj.CreateShortcut($PSItem.FullName)

      $info = [ordered]@{}
      $info.Name       = $PSItem.Name
      $info.LinkPath   = $link.FullName
      $info.TargetPath = $link.TargetPath
      $info.Arguments  = $link.Arguments
      $info.Target     = try { Split-Path $info.TargetPath -Leaf } catch { 'n/a'}

      New-Object -TypeName PSObject -Property $info
    }
}

# Get-Shortcut $env:UserProfile\Desktop; # | select-object -Property Link, Target, Arguments;
# | Where-Object ($_.Target -eq 'pnagent.exe'); # | Format-Table -Property Link, Target, Arguments -AutoSize

$Path = "$Env:ProgramData\Microsoft\Windows\Start Menu\Programs"

# Got all local shortcuts ... originally created to 'harvest' shortcuts from a XenApp / RDS server session.
$global:shortcuts = @{} # new hash table
Get-ChildItem -Path $Path -Recurse | 
foreach {
#    Write-Output -InputObject " > $(Split-Path -Path $(Split-Path -Path $PSItem.FullName -Parent) -Leaf) : "
    Get-Shortcut -Path $PSItem.FullName | Sort-Object -Unique -Descending | 
    ForEach-Object -Process {
#        if ($lnk.Target  ) { # -like '*.exe' ) {
            try {
                $global:shortcuts += @{$PSItem.Target = $PSItem.LinkPath} # $shortcuts + 
            }
            catch {
                # Write-Output -InputObject "warning: duplicate shortcut target already defined`n$($PSItem.Target) : $($PSItem.LinkPath)"
            }
    }
}
Write-Output -InputObject "Successfully mapped $($shortcuts.Count) shortcuts."

function Start-Shortcut {
  param(
        [Parameter(Mandatory = $false,
            Position = 0,
            ValueFromPipeline = $true,
            HelpMessage = 'Folder path to look for .lnk shortcuts'
        )]
        [ValidateScript({"$PSItem" -in $global:shortcuts.Keys})]
        [string]
        $Name = 'SnippingTool'
  )

    Write-Output -InputObject "Starting $Name : $($shortcuts.$Name)"
    & $shortcuts.$Name
}

# Get-Shortcut $env:UserProfile\Desktop; # | select-object -Property Link, Target, Arguments;
# | Where-Object ($_.Target -eq 'pnagent.exe'); # | Format-Table -Property Link, Target, Arguments -AutoSize

function Show-Shortcut {
  param(
        [Parameter(
            Mandatory = $false,
            Position = 0,
            ValueFromPipeline = $true,
            HelpMessage = 'Folder path to look for .lnk shortcuts'
        )]
        [ValidateScript({"$PSItem" -in $global:shortcuts.Keys})]
        [string]
        $Key = 'SnippingTool',

        [Parameter(
            Mandatory = $false,
            Position = 1
        )]
        [switch]
        $All = $false
  )

if ($All) {
    foreach ($sc in $($global:shortcuts.Keys |  Sort-Object -Property Values)) {
        $showPath = $global:shortcuts.$sc -replace 'C:\\ProgramData\\Microsoft\\Windows\\Start Menu\\Programs\\'
        $props = @{
            ShortcutName = $sc.Name
            LinkTarget = $showPath
        }
        New-Object -TypeName psobject -Property $props
#        Write-Output -InputObject "$showPath `n`t$sc`n"
    }

  } else {
        $showPath = $global:shortcuts.$Key -replace 'C:\\ProgramData\\Microsoft\\Windows\\Start Menu\\Programs\\'
        $props = @{
            ShortcutName = $Key
            LinkTarget = $showPath
        }
        New-Object -TypeName psobject -Property $props
#        Write-Output -InputObject "$showPath `n`t$sc`n"
  }
}