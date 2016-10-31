# https://technet.microsoft.com/library/security/3009008
# Microsoft Security Advisory 3009008
# Vulnerability in SSL 3.0 Could Allow Information Disclosure

# Implement workaround via Registry edit
# Intended to be run on/applied to the local machine, either via interactive console or WinRM

# To run remotely:
# Invoke-Command -Credential $my2acct -Authentication Credssp -EnableNetworkAccess -ComputerName GBCI02VMLOC01 -FilePath \\gbci02psh01\PS-Repo\Systems\Msft_SecAdv_3009008.ps1
# To create test-condition, first run:
# Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server' -Name 'Enabled' -Value 1

# 'gbci02vc01','gbci02vcum01',',gbci02veeam01','gbci02vmloc01','gbci91vc01'

# Invoke-Command -Credential $my2acct -Authentication Credssp -EnableNetworkAccess -ComputerName gbci02vc01, gbci02vcum01, gbci02veeam01, gbci02vmloc01, gbci91vc01 -ScriptBlock { Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Server' -Name 'Enabled' -Value 0 -ErrorAction SilentlyContinue; Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\Client' -Name 'Enabled' -Value 0 -ErrorAction SilentlyContinue} 

[string]$MyName = $($MyInvocation.MyCommand).Name

Write-Debug -Message "Starting $MyName on $Env:COMPUTERNAME"

Write-Output -InputObject 'Declaring function Set-SSL3Disabled'
function Set-SSL3Disabled {
<#
'Client','Server' | ForEach {
    $regPath = "$SSL3_Key\$PSItem"
    if (test-path -Path $regPath -PathType Container)
    {
        if ((Get-ItemProperty -Path $regPath -Name 'Enabled').'Enabled' -eq 0)
        {
            Write-Output "$MyName`: Disabling SSL 3.0 Web $PSItem support"
            Write-EventLog -LogName 'Windows PowerShell' -Source 'PowerShell' -EntryType Information -Message "$MyName`: Disabling SSL 3.0 Web $PSItem support" -EventId 301
            Set-ItemProperty -Path $regPath -Name 'Enabled' -Value 1
        }
        else
        {
            Write-Output "$MyName`: SSL 3.0 Web $PSItem support already disabled (by registry)"
            Write-EventLog -LogName 'Windows PowerShell' -Source 'PowerShell' -EntryType Information -Message "$MyName`:SSL 3.0 Web $PSItem support already disabled (by registry)" -EventId 302
        }
    } 
}
#>

    $SCHANNEL_Key = 'HKLM:\System\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'

    Get-ChildItem -path $SCHANNEL_Key -Recurse | ForEach { 
        Get-ChildItem -path $PSItem -Recurse | ForEach { 
            $KeyPathString = $PSItem.Name.Replace('HKEY_LOCAL_MACHINE\','HKLM:\').ToString() 
            if ((Get-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\$PSItem\Client" -Name 'Enabled').Enabled -ne 0)
            {
                Write-Output "Disabling SSL 3.0 Web $PSItem support"
                Write-EventLog -LogName 'Windows PowerShell' -Source 'PowerShell' -EntryType Information -Message "Disabling SSL 3.0 Web $PSItem support" -EventId 301
                Set-ItemProperty -Path "HKLM:\System\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\SSL 3.0\$PSItem" -Name 'Enabled' -Value 0 -ErrorAction SilentlyContinue
            }
        } 
    }
}

Write-Output -InputObject 'Declaring function Get-TLSProtocols'
function Get-TLSProtocols
{
# Get SCHANNEL Protocol, endpoint, and Enabled value from (local) registry
# Thanks to: https://connect.microsoft.com/PowerShell/feedback/details/632464/get-itemproperty-in-registry-should-return-value-type

$SCHANNEL_Key = 'HKLM:\System\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols'

# Setup shell of default properties for object to be returned by this function
$Private:properties = [ordered]@{
    'Protocol'   = 'N/A'
    'Endpoint'   = 'N/A'
    'Property'       = 'N/A'
    'Value'      = 'N/A'
    'Value Type' = 'N/A'
}
$Private:RetObject = New-Object -TypeName PSObject -Property $properties

    Write-Debug -Message "Get-ChildItem -path $SCHANNEL_Key -Recurse"
    Get-ChildItem -path $SCHANNEL_Key -Recurse | ForEach {
        $KeyPathString = $PSItem.Name.Replace('HKEY_LOCAL_MACHINE\','HKLM:\').ToString()       
        Write-Debug -Message "`$KeyPathString: $KeyPathString" 

        if (Get-ItemProperty -Path $KeyPathString -Name 'Enabled' -ErrorAction SilentlyContinue)
        {
            $key = Get-Item -Path $([System.Convert]::ToString($KeyPathString)).replace('\Enabled','')
            Write-Debug -Message "Checking `$key: $key" 
            
            # Pull Protocol name and endpoint (e.g. Client or Server) from reg path
            $Tokens = $KeyPathString -split '\\'
            $Protocol = $Tokens.GetValue(($Tokens.Count)-2)
            $Endpoint = $Tokens.GetValue(($Tokens.Count)-1)
            Write-Debug -Message "`$Protocol: $Protocol" 
            Write-Debug -Message "`$Endpoint: $Endpoint" 

            # These REG values are / should be DWORD
            $ValueType = $key.GetValueKind('Enabled')
            $Value = $key.GetValue('Enabled')
            Write-Debug -Message "`$ValueType: $ValueType" 
            Write-Debug -Message "`$Value: $Value" 

            $Private:properties = [ordered]@{
                'Protocol'   = $Protocol
                'Endpoint'   = $Endpoint
                'Property'   = 'Enabled'
                'Value'      = $Value
                'Value Type' = $ValueType
            }

            Write-Debug -Message $properties
        } # end if Enabled
        $Private:RetObject = New-Object -TypeName PSObject -Property $properties
    } # end foreach
    return $RetObject | Format-Table -AutoSize
}

<#

[ ] Mirror over to GitHub or UserVoice?
https://connect.microsoft.com/PowerShell/feedback/details/632464/get-itemproperty-in-registry-should-return-value-type

Currently I see no easy way to get type of registry values. Info presented by Get-ItemProperty is not very helpful. I found workaround for that (sample): 
$key = Get-Item 'HKLM:\software\Microsoft\windows\CurrentVersion\policies\Explorer'
$Property = @{Name = 'Property'; Expression = {$PSItem}}
$Value = @{Name = 'Value'; Expression = {$key.GetValue($PSItem) }}
$ValueType = @{Name = 'Value Type'; Expression = {$key.GetValueKind($PSItem)}}
$key.Property | select $Property, $Value, $ValueType
I think it would be better if Get-ItemProperty would return type too.
#>
