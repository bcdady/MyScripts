# https://community.rackspace.com/products/f/25/t/507
# This posting is primarily aimed at customers who are running PCI compliance scans and are of disabling certain protocols to pass the PCI compliance scan.</p>
# The following script block includes elements to disable certain weak encryption mechanisms using registry edits.&nbsp; After running any element of the script it will be necessary to reboot your Windows server in order to fully apply these changes.</p>

#make TSL 1.2 protocol reg keys
$SCHANNELPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders\SCHANNEL\Protocols\TLS 1.2'
New-Item -Path ('{0}\Protocols\TLS 1.2' -f $SCHANNELPath)
New-Item -Path ('{0}\Protocols\TLS 1.2\Server' -f $SCHANNELPath)
New-Item -Path ('{0}\Protocols\TLS 1.2\Client' -f $SCHANNELPath)

# Enable TLS 1.2 for client and server SCHANNEL communications
New-ItemProperty -Path ('{0}\Protocols\TLS 1.2\Server' -f $SCHANNELPath) -name 'Enabled' -value 1 -PropertyType 'DWord'
New-ItemProperty -Path ('{0}\Protocols\TLS 1.2\Server' -f $SCHANNELPath) -name 'DisabledByDefault' -value 0 -PropertyType 'DWord'
New-ItemProperty -Path ('{0}\Protocols\TLS 1.2\Client' -f $SCHANNELPath) -name 'Enabled' -value 1 -PropertyType 'DWord'
New-ItemProperty -Path ('{0}\Protocols\TLS 1.2\Client' -f $SCHANNELPath) -name 'DisabledByDefault' -value 0 -PropertyType 'DWord'

# Make and Enable TLS 1.1 for client and server SCHANNEL communications
New-Item -Path ('{0}\Protocols\TLS 1.1' -f $SCHANNELPath)
New-Item -Path ('{0}\Protocols\TLS 1.1\Server' -f $SCHANNELPath)
New-Item -Path ('{0}\Protocols\TLS 1.1\Client' -f $SCHANNELPath) 
New-ItemProperty -Path ('{0}\Protocols\TLS 1.1\Server' -f $SCHANNELPath) -name 'Enabled' -value 1 -PropertyType 'DWord'
New-ItemProperty -Path ('{0}\Protocols\TLS 1.1\Server' -f $SCHANNELPath) -name 'DisabledByDefault' -value 0 -PropertyType 'DWord'
New-ItemProperty -Path ('{0}\Protocols\TLS 1.1\Client' -f $SCHANNELPath) -name 'Enabled' -value 1 -PropertyType 'DWord'
New-ItemProperty -Path ('{0}\Protocols\TLS 1.1\Client' -f $SCHANNELPath) -name 'DisabledByDefault' -value 0 -PropertyType 'DWord'

# Disable SSL 2.0
New-Item -Path ('{0}\Protocols\SSL 2.0\Server' -f $SCHANNELPath)
New-ItemProperty -Path ('{0}\Protocols\SSL 2.0\Server' -f $SCHANNELPath) -name Enabled -value 0 -PropertyType 'DWord'

# Enable SSL 3.0
New-Item -Path ('{0}\Protocols\SSL 3.0\Server' -f $SCHANNELPath)
New-ItemProperty -Path ('{0}\Protocols\SSL 3.0\Server' -f $SCHANNELPath) -name Enabled -value 1 -PropertyType 'DWord'

#Disable Weak Cyphers

New-Item -Path ('{0}\Ciphers\Null' -f $SCHANNELPath)
New-ItemProperty -Path ('{0}\Ciphers\Null' -f $SCHANNELPath) -name 'Enabled' -value 0 -PropertyType 'Dword'

New-Item -Path ('{0}\Ciphers\DES 56' -f $SCHANNELPath) 
New-Item -Path ('{0}\Ciphers\DES 56/56' -f $SCHANNELPath) 
New-ItemProperty -Path ('{0}\Ciphers\DES 56/56' -f $SCHANNELPath) -name 'Enabled' -value 0 -PropertyType 'Dword'

New-Item -Path ('{0}\Ciphers\RC2 40' -f $SCHANNELPath) 
New-Item -Path ('{0}\Ciphers\RC2 40/128' -f $SCHANNELPath) 
New-ItemProperty -Path ('{0}\Ciphers\RC2 40/128' -f $SCHANNELPath) -name 'Enabled' -value 0 -PropertyType 'Dword'

New-Item -Path ('{0}\Ciphers\RC2 56' -f $SCHANNELPath) 
New-Item -Path ('{0}\Ciphers\RC2 56/128' -f $SCHANNELPath) 
New-ItemProperty -Path ('{0}\Ciphers\RC2 40/128' -f $SCHANNELPath) -name 'Enabled' -value 0 -PropertyType 'Dword'

New-Item -Path ('{0}\Ciphers\RC2 128' -f $SCHANNELPath) 
New-Item -Path ('{0}\Ciphers\RC2 128/128' -f $SCHANNELPath)  
New-ItemProperty -Path ('{0}\Ciphers\RC2 128/128' -f $SCHANNELPath) -name 'Enabled' -value 0 -PropertyType 'Dword'

New-Item -Path ('{0}\Ciphers\RC4 40' -f $SCHANNELPath) 
New-Item -Path ('{0}\Ciphers\RC4 40/128' -f $SCHANNELPath) 
New-ItemProperty -Path ('{0}\Ciphers\RC4 40/128' -f $SCHANNELPath) -name 'Enabled' -value 0 -PropertyType 'Dword'

New-Item -Path ('{0}\Ciphers\RC4 56' -f $SCHANNELPath) 
New-Item -Path ('{0}\Ciphers\RC4 56/128' -f $SCHANNELPath) 
New-ItemProperty -Path ('{0}\Ciphers\RC4 56/128' -f $SCHANNELPath) -name 'Enabled' -value 0 -PropertyType 'Dword'

New-Item -Path ('{0}\Ciphers\RC4 64' -f $SCHANNELPath) 
New-Item -Path ('{0}\Ciphers\RC4 64/128' -f $SCHANNELPath) 
New-ItemProperty -Path ('{0}\Ciphers\RC4 64/128' -f $SCHANNELPath) -name 'Enabled' -value 0 -PropertyType 'Dword'

#Enable Strong Cyphers

New-Item -Path ('{0}\Ciphers\RC4 128' -f $SCHANNELPath) 
New-Item -Path ('{0}\Ciphers\RC4 128/128' -f $SCHANNELPath) 
New-ItemProperty -Path ('{0}\Ciphers\RC4 128/128' -f $SCHANNELPath) -name 'Enabled' -value 1 -PropertyType 'Dword'

New-Item -Path ('{0}\Ciphers\Triple DES 168' -f $SCHANNELPath) 
New-Item -Path ('{0}\Ciphers\Triple DES 168/168' -f $SCHANNELPath) 
New-ItemProperty -Path ('{0}\Ciphers\Triple DES 168/168' -f $SCHANNELPath) -name 'Enabled' -value 1 -PropertyType 'Dword'

New-Item -Path ('{0}\Ciphers\AES 128' -f $SCHANNELPath) 
New-Item -Path ('{0}\Ciphers\AES 128/128' -f $SCHANNELPath) 
New-ItemProperty -Path ('{0}\Ciphers\AES 128/128' -f $SCHANNELPath) -name 'Enabled' -value 1 -PropertyType 'Dword'

New-Item -Path ('{0}\Ciphers\AES 256' -f $SCHANNELPath) 
New-Item -Path ('{0}\Ciphers\AES 256/256' -f $SCHANNELPath) 
New-ItemProperty -Path ('{0}\Ciphers\AES 256/256' -f $SCHANNELPath) -name 'Enabled' -value 1 -PropertyType 'Dword'

