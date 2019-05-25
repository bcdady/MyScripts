
<#
    https://gbci02aweb1/assystweb/application.do#welcome%2FWelcomeDispatchAction.do%3Fdispatch%3Drefresh
    Example 21-3. Adding www.example.com to the list of trusted sites in Internet Explorer

    Set-Location "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    Set-Location ZoneMap\Domains
    New-Item example.com
    Set-Location example.com
    New-Item www
    Set-Location www
    New-ItemProperty . -Name http -Value 2 -Type DWORD
#>

$ZoneMapDomainsPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap\Domains'
if (-not (Test-Path -Path $ZoneMapDomainsPath)) {
    New-Item -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\ZoneMap' -Name 'Domains' -ItemType 'RegistryKey'
}

New-Item -Path $ZoneMapDomainsPath -Name 'michaelhyatt.com'
New-Item -Path "$ZoneMapDomainsPath\michaelhyatt.com" -Name '*'
New-ItemProperty -Path "$ZoneMapDomainsPath\michaelhyatt.com\*\" -Name http -Value 2 -Type DWORD

New-Item -Path $ZoneMapDomainsPath -Name 'infusionsoft.com'
New-Item -Path "$ZoneMapDomainsPath\infusionsoft.com" -Name 'an136'
New-ItemProperty -Path "$ZoneMapDomainsPath\infusionsoft.com\an136\" -Name http -Value 2 -Type DWORD
