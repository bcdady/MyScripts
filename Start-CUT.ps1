#requires -Version 3.0 -Modules ContactsUpdate,PSLogger

<#
    Author: Bryan
    Version: 1.0
    Last Updated: 2016-03-16

    Purpose: Import Contact Update Tool module, and run primary functions, for use as a scheduled task
#>

[cmdletbinding(SupportsShouldProcess)]
param()


# Define $loggingPath for Write-Log function, from PSLogger module
Initialize-Logging -Path $(Join-Path -Path $env:SystemDrive -ChildPath logs)

Write-Log -Message "Starting ContactsUpdate Scheduled Task as $env:USERNAME" -Function ContactsUpdate

# Get-CUInputFile is not working as expected, returning both string and File.IO objects, so we're skipping it for now
Get-ChildItem -Path \\hcdata\GBCI\Shared\Corporate\IT\AD-HR\*.csv | Sort-Object -Property LastWriteTime -Descending | ForEach-Object -Process { Update-ADUser -Path $($PSItem.FullName) }
# Sort-Object -Property LastWriteTime -Descending

Write-Log -Message "Ended  ContactsUpdate Scheduled Task. Additional detail may be found in the most recent log file:`n$((Get-LatestLog -Count 1).FullName)" -Function ContactsUpdate


# SIG # Begin signature block
# MIIEEwYJKoZIhvcNAQcCoIIEBDCCBAACAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUE0HrjwQooH7bamKq5ygi9RrU
# CnSgggIoMIICJDCCAZGgAwIBAgIQAdyuYRuEhqdCtx77uK9/LTAJBgUrDgMCHQUA
# MCExHzAdBgNVBAMTFlBTSDAxIENlcnRpZmljYXRlIFJvb3QwHhcNMTYwNDI3MjI0
# MjI4WhcNMzkxMjMxMjM1OTU5WjAbMRkwFwYDVQQDExBQb3dlclNoZWxsIGJkYWR5
# MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDVptZLHFmDFcNf2zK0THUk8eBV
# YTEtiWrjo8cnfQhZ2kCzwjHu5Z1Jyo5feedxoFPtCuYvtV65cozlWHjj/XSB1lQB
# GOnbwS8WpoL3bDypuXQGQSjGtB89E1z6m/CXB/lWKxC41aZWFK1eMfi0V5CLM10I
# oXIYW3HOo/Fw9HWxHwIDAQABo2swaTATBgNVHSUEDDAKBggrBgEFBQcDAzBSBgNV
# HQEESzBJgBBP05mwd7DH2mDjV5ob8Z6zoSMwITEfMB0GA1UEAxMWUFNIMDEgQ2Vy
# dGlmaWNhdGUgUm9vdIIQZh+Kjc3NFohMfhnaa+3LeDAJBgUrDgMCHQUAA4GBAIjM
# Z2F0nW4e2qZD0yZdedS1OQw8hy+T7XNFYJncBgrHbVyUJIa5nK7enGbQWOEayxgp
# 22bRPEdl/qjk/tgoGojSbWD7KGCrefiP+H/HTBDeopmtq/igrt6FJ9q2JB0Mh5Kv
# 9TQZfeVBbLvlw5HrtVhgGJ6ZyZwFwTmjw95yjEqUMYIBVTCCAVECAQEwNTAhMR8w
# HQYDVQQDExZQU0gwMSBDZXJ0aWZpY2F0ZSBSb290AhAB3K5hG4SGp0K3Hvu4r38t
# MAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqGSIb3
# DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEV
# MCMGCSqGSIb3DQEJBDEWBBSmKEXL+npPDO/kx5BM09QLG1Qw4TANBgkqhkiG9w0B
# AQEFAASBgJ64gWncwkemnWC9HYzIvz9tu8vfsGlQw1bxECosyHaKClAQTyvIJyA6
# zzcFml5EIGmXBNfe3jnDVhP7d4eysjzfWaNnMaoELqBKW6W6hD1TvQIfKXqX6dRU
# Pqr5e9diJgb2zvhljyBr3TRxFKtYMprjkVGI2uwkHqCVrlA4EjgX
# SIG # End signature block
