#!/usr/local/bin/pwsh
#Requires -Version 3 -Module GroupPolicy

# Developed as an PowerShell native alternative to SDM-GPOExporter

function Convert-SOMPathToDN ($SOMPath) {
    # convert from SOMPath format: domainName.TLD/ouName/anotherOU to DistinguishedName format: OU=anotherOU,OU=ouName,DC=domainName,DC=local

    Write-Verbose -Message ('Processing SOMPath: {0}' -f $SOMPath)
    $OUToken = ($SOMPath -split '/')
    Write-Verbose -Message ('$OUToken.Count: {0}' -f $OUToken.Count)
    $ctr = ($OUToken.Count)-1
    
    # Replace '.' with DC= in the first OUToken, presuming it's a period delimited domain name
    $domain = 'DC={0}' -f $OUToken[0] -replace '\.',',DC='
    Write-Verbose -Message ('$domain: {0}' -f $domain)
    
    $OUArray = [System.Collections.ArrayList]@()
    do {
        Write-Verbose -Message ('OU={0}' -f $OUToken[$ctr])

        $Null = $OUArray.Add('OU={0}' -f $OUToken[$ctr])
        $ctr--
    } until ($ctr -eq 0)

    return ('{0},{1}' -f ($OUArray -join ','), $domain)
}

$PolicyName = '1ST COMPUTER PRODUCTION POLICY'
# $CSVLiteralPath = '\\sharePath\GPO\Policy_Report.csv'

#$GPOReportXML = (Get-GPOReport -Name $PolicyName -ReportType Xml)
$thisPolicy = [System.Xml.XmlDocument](Get-GPOReport -Name $PolicyName -ReportType Xml)

# Confirm we got viable content in $thisPolicy
if (Select-Object -InputObject $thisPolicy -Property GPO) {
    Write-Verbose -Message ('Evaluating GPO {0}' -f $thisPolicy.GPO.Name) -Verbose
} else {
    # Write-Warning -Message ('(Get-GPOReport -Name {0} -ReportType Xml) Failed!' -f $PolicyName)
    throw ('(Get-GPOReport -Name {0} -ReportType Xml) Failed!' -f $PolicyName)
}

#$PolicySettings = @{}
$Ccounter = 0
$Ucounter = 0

$Private:ComputerSettings = [System.Collections.ArrayList]@()
$Private:UserSettings     = [System.Collections.ArrayList]@()

$thisPolicy.GPO | ForEach-Object -Process {

    $Private:properties = [ordered]@{
        'Name'         = $_.Name
        'UniqueID'     = $_.Identifier.Identifier.'#text'
        'ModifiedTime' = $_.ModifiedTime
        'Links'        = $_.LinksTo | ForEach-Object -Process { $PSItem | Select-Object -Property @{ Label='Name'; Expression={$_.SOMName}}, @{ Label='DistinguishedName'; Expression={ Convert-SOMPathToDN($_.SOMPath)} }, Enabled, NoOverride }
    }

    # Enumerate Computer Configuration Extension Settings and Values
    if ($_.Computer.Enabled -eq $true) {

        $thisPolicy.GPO.Computer.ExtensionData.Extension.Policy | Where-Object -FilterScript { $null -ne $_.Name } | ForEach-Object -Process {
            
            Write-Verbose -Message ('Processing SettingName: {0}' -f $_.Name) -Verbose

            $thisSetting  = [ordered]@{
                'Name'    = $_.Name
                'State'   = $_.State
                'Value'   = $_.ListBox.Value.Element.Data
            }

            # add an entry to the parent hashtable, with a key for this setting name, and a value a hashtable including this settings details
            ('Adding to properties: {0} : {1}' -f $thisSetting.Context, $_.Name)
            #$Private:properties[('{0}_{1}' -f $thisSetting.Context, $_.Name)] = $thisSetting
            $Private:ComputerSettings.Add($thisSetting)
        }

        $Private:properties['Computer'] = $Private:ComputerSettings

    } else {

        Write-Verbose -Message 'No User Settings for this policy' -Verbose

    }


    # Enumerate User Configuration Extension Settings and Values
    if ($_.User.Enabled -eq $true) {

        $thisPolicy.GPO.User.ExtensionData.Extension.Policy | Where-Object -FilterScript { $null -ne $_.Name } | ForEach-Object -Process {

            Write-Verbose -Message ('Processing SettingName: {0}' -f $_.Name) -Verbose

            $thisSetting  = [ordered]@{
                'Name'    = $_.Name
                'State'   = $_.State
                'Value'   = $_.ListBox.Value.Element.Data
            }

            # add an entry to the parent hashtable, with a key for this setting name, and a value a hashtable including this settings details
            Write-Verbose -Message ('Adding to properties: {0} : {1}' -f $thisSetting.Context, $_.Name)
            #$Private:properties[('{0}_{1}' -f $thisSetting.Context, $_.Name)] = $thisSetting
            $Private:UserSettings.Add($thisSetting)
        }

        $Private:properties['User'] = $Private:UserSettings

    } else {

        Write-Verbose -Message 'No User Settings for this policy' -Verbose

    }

    <#
    $Private:properties = [ordered]@{
        'Name'               = $thisPolicy.GPO.Name
        'UniqueID'           = $thisPolicy.GPO.Identifier.Identifier.'#text'
        'ModifiedTime'       = $thisPolicy.GPO.ModifiedTime
        'Links'              = $thisPolicy.GPO.LinksTo
        'SettingName'        = $thisPolicy.GPO.Computer.ExtensionData.Extension.Policy.Name
        'SettingState'       = $thisPolicy.GPO.Computer.ExtensionData.Extension.Policy.State
        'SettingValue'       = $thisPolicy.GPO.Computer.ExtensionData.Extension.Policy.ListBox.Value | Select-Object -ExpandProperty Element
    }
    #>

    'Creating new object as $GPO'
    $GPO = (New-Object -TypeName PSObject -Property $Private:properties)
    return (New-Object -TypeName PSObject -Property $Private:properties)
}
