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
    $path = $null
  )

  $obj = New-Object -ComObject WScript.Shell

  if ($path -eq $null) {
    $pathUser = [System.Environment]::GetFolderPath('Desktop')
    # $pathCommon = $obj.SpecialFolders.Item('AllUsersStartMenu')
    $path = Get-ChildItem $pathUser, $pathCommon -Filter *.lnk -Recurse 
  }
  if ($path -is [string]) {
    $path = Get-ChildItem $path -Filter *.lnk
  }
  $path | ForEach-Object { 
    if ($_ -is [string]) {
      $_ = Get-ChildItem $_ -Filter *.lnk
    }
    if ($_) {
      $link = $obj.CreateShortcut($_.FullName)

      $info = @{}
      $info.Hotkey = $link.Hotkey
      $info.TargetPath = $link.TargetPath
      $info.LinkPath = $link.FullName
      $info.Arguments = $link.Arguments
      $info.Target = try {Split-Path $info.TargetPath -Leaf } catch { 'n/a'}
      $info.Link = try { Split-Path $info.LinkPath -Leaf } catch { 'n/a'}
      $info.WindowStyle = $link.WindowStyle
      $info.IconLocation = $link.IconLocation

      New-Object PSObject -Property $info
    }
  }
}

Get-Shortcut $env:UserProfile\Desktop; # | select-object -Property Link, Target, Arguments;
# | Where-Object ($_.Target -eq 'pnagent.exe'); # | Format-Table -Property Link, Target, Arguments -AutoSize
