$ErrorActionPreference = 'Inquire'
Write-Output -InputObject 'Dot-sourcing shortcut functions ...'

Write-Output -InputObject 'Declaring function Get-Shortcut'
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
        [Parameter(
            Position = 0,
            ValueFromPipeline = $true,
            HelpMessage = 'Folder path to look for .lnk shortcuts'
        )]
        [ValidateScript({Test-Path -Path $PSItem})]
        [string]
        $path = "$Env:ProgramData\Microsoft\Windows\Start Menu\Programs" # $(Join-Path -Path $env:UserProfile -ChildPath 'Desktop')
  )

  $WSCShell = New-Object -ComObject WScript.Shell

<#  if ($path -eq $null) {
    $pathUser = [System.Environment]::GetFolderPath('Desktop')
    # $pathCommon = $WSCShell.SpecialFolders.Item('AllUsersStartMenu')
    $path = Get-ChildItem $pathUser, $pathCommon -Filter *.lnk -Recurse 
  }
#>
    $Private:RetObject = New-Object -TypeName PSObject
    $global:shortcuts = @()

    Write-Debug -Message "Get-ChildItem $path -Filter *.lnk"
    Get-ChildItem $path -Filter *.lnk -Recurse | ForEach-Object -Process {
        Write-Debug -Message "Getting shortcut info for $($PSItem.FullName)"
        $link = $WSCShell.CreateShortcut($PSItem.FullName)

        $linkArguments = ''
        try 
        {
            Test-Path -Path $link.TargetPath -PathType Leaf | out-null
            $linkTarget = Split-Path $link.TargetPath -Leaf

            if ($link.Arguments) { $linkArguments = $link.Arguments }
            $private:properties = [ordered]@{
                'Name'        = $($PSItem.Name  -replace "\s",'').Replace('.lnk','')
                'Target'      = $linkTarget
                'Arguments'   = $linkArguments
                'Description' = $link.Description
                'FullName'    = $link.FullName
            }
            #    'BaseName'    = $($link.FullName | Split-Path $link.TargetPath -Parent)

            # Instantiate custom object with these properties
            $Private:RetObject = New-Object -TypeName PSObject -Property $private:properties

            # Append the current object instance to the collection of objects to be returned
            $global:shortcuts += $Private:RetObject
        }
        catch
        {
            Write-Debug -Message "Skipping invalid shortcut -- Failed to validate TargetPath for $($PSItem.FullName)"
    }
}

# Get-Shortcut $env:UserProfile\Desktop; # | select-object -Property Link, Target, Arguments;
# | Where-Object ($_.Target -eq 'pnagent.exe'); # | Format-Table -Property Link, Target, Arguments -AutoSize
    # $Path = "$Env:ProgramData\Microsoft\Windows\Start Menu\Programs"

# Got all local shortcuts ... originally created to 'harvest' shortcuts from a XenApp / RDS server session.
    <#$global:shortcuts = @{} # new hash table
    Get-ChildItem -Path $Path -Filter *.lnk -Recurse | 
foreach {
#    Write-Output -InputObject " > $(Split-Path -Path $(Split-Path -Path $PSItem.FullName -Parent) -Leaf) : "
    Get-Shortcut -Path $PSItem.FullName | Sort-Object -Unique -Descending | 
    ForEach-Object -Process {
            try {
                $global:shortcuts += @{$PSItem.Target = $PSItem.LinkPath} # $shortcuts + 
                Write-Debug -Message "Added shortcuts target: $($PSItem.Target) with LinkPath $($PSItem.LinkPath)" 
            }
            catch {
                Write-Debug -Message "Warning: Duplicate shortcut target or other unexpected issue with PSItem:`n$PSItem"
            }
    }
}
    #>
    Write-Output -InputObject "Successfully mapped $($global:shortcuts.Count) shortcuts."
}

Write-Output -InputObject 'Declaring function Start-Shortcut'
function Start-Shortcut {
  param(
        [Parameter(
            Position = 0,
            ValueFromPipeline = $true,
            HelpMessage = 'Folder path to look for .lnk shortcuts'
        )]
        [ValidateScript({foreach ($key in $global:shortcuts.Name) { Write-Output ('Comparing {0}* with {1}' -f $key, $PSItem); if ($myApp -like "$PSItem*") { Write-Output -InputObject "$myApp matched $app"; return $true } }})]
        [string]
        $Name = 'SnippingTool'
  )

    Write-Output -InputObject "Starting $Name : $($shortcuts.$Name)"
    & $shortcuts.$Name
}

# Get-Shortcut $env:UserProfile\Desktop; # | select-object -Property Link, Target, Arguments;
# | Where-Object ($_.Target -eq 'pnagent.exe'); # | Format-Table -Property Link, Target, Arguments -AutoSize

Write-Output -InputObject 'Declaring function Show-Shortcut'
function Show-Shortcut {
  param(
        [Parameter(
            Position = 0,
            ValueFromPipeline = $true,
            HelpMessage = 'Folder path to look for .lnk shortcuts'
        )]
        [string]
        $Key = 'SnippingTool',

        [Parameter(
            Mandatory = $false,
            Position = 1
        )]
        [switch]
        $All = $false
  )
#    [ValidateScript({$global:shortcuts.Name -in "$PSItem*"})]

if ($All) {
    foreach ($sc in $($global:shortcuts.Name |  Sort-Object -Property Values)) {
        $showPath = $global:shortcuts.$sc -replace 'C:\\ProgramData\\Microsoft\\Windows\\Start Menu\\Programs\\'
        $props = @{
            ShortcutName = $sc.Name
            LinkTarget = $showPath
        }
        New-Object -TypeName psobject -Property $props
    }

  } else {
        $showPath = $global:shortcuts.$Key -replace 'C:\\ProgramData\\Microsoft\\Windows\\Start Menu\\Programs\\'
        $props = @{
            ShortcutName = $Key
            LinkTarget = $showPath
        }
        New-Object -TypeName psobject -Property $props
  }
}