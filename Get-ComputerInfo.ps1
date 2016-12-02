#################################################
#
# Modified by:  Bryan Dady (@bcdady)
# Last Modified:  10/10/2016
# Purpose:  To collect and display useful computer information
#           Collects info for localhost by default, but you can change localhost to a machine name and hit the "Get Info" button to get remote machine info
# Original GUI version Written by:  Joshua D. True, Last Modified:  05/22/2015 07:52:17
#
#################################################
 
#Import Show UI Module
#Import-Module ShowUI -ErrorAction SilentlyContinue

#Create a Stack Panel to add required Controls
#New-StackPanel -ControlName 'Computer Information' {


# Need to add function parameter(s) to accept ComputerName for retrieving system info from a remote machine

#    New-Label "Enter Machine Name:" -Background DarkRed -Foreground white -FontWeight Bold -Margin (3,3,0,0) -VerticalContentAlignment Bottom
#    New-TextBox -Name MachineName -Text localhost -Foreground DarkRed -FontWeight Bold -Margin (3,3,0,0) -HorizontalAlignment Right -HorizontalContentAlignment Right -MinWidth 200 -VerticalContentAlignment Bottom -Column 1 -On_Loaded {

        #Set variables for initial load
        [float] $levelWarn  = 20.0;  # Warn-level in percent. 
        [float] $levelAlarm = 10.0;  # Alarm-level in percent. 
        $BIOS = Get-WmiObject -Class Win32_BIOS -ComputerName $MachineName.Text 
        $OS = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $MachineName.Text
        $CompSys = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $MachineName.Text
        $CPU = Get-WmiObject -Class Win32_Processor -ComputerName $MachineName.Text
        $LogDisk = Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType = 3" -ComputerName $MachineName.Text
        $RAM1 = Get-WmiObject -Class Win32_PhysicalMemoryArray -ComputerName $MachineName.Text
        $RAM2 = Get-WmiObject -Class Win32_PhysicalMemory -ComputerName $MachineName.Text
        $dateTime = Get-Date
        
        # Build custom object of info to return / display
        
        #Fill textboxes with initial values for localhost when loaded
        $ComputerName.Text = $BIOS.PSComputerName
        $ComputerDomain.Text = $CompSys.Domain
        $ComputerDescription.Text = $OS.Description
        $Manufacturer.Text = $BIOS.Manufacturer
        $Model.Text = $CompSys.Model
        $SerialNum.Text = $BIOS.SerialNumber
        $BIOSVer.Text = $BIOS.smBIOSBIOSVersion 
        $OperatingSystem.Text = $OS.Caption, $OS.CSDVersion
        $Mem.Text = "{0:N0} GB" -f ($CompSys.TotalPhysicalMemory / 1GB) + " | " + ($RAM2.DeviceLocator).Count + " Modules Installed | " + $RAM1.MemoryDevices + " Total Slots | " + ($RAM1.MemoryDevices-($RAM2.DeviceLocator).Count) + " Empty Slots"
        $CPUDesc.Text = $CPU.NumberOfCores, "Cores @", "{0:N1} GHz" -f ($CPU.MaxClockSpeed / 1024) 
        $HDInfo1 = @()
        ForEach ($disk in $LogDisk){$HDInfo1 += $disk.DeviceID}
        $HD1.ItemsSource = $HDInfo1
        $HDInfo2 = @()
        ForEach ($disk in $LogDisk){$HDInfo2 += $disk.VolumeName}
        $HD2.ItemsSource = $HDInfo2
        $HDInfo3 = @()
        ForEach ($disk in $LogDisk){$HDInfo3 += "{0:N2}" -f ($disk.Size/1073741824)}
        $HD3.ItemsSource = $HDInfo3
        $HDInfo4 = @()
        ForEach ($disk in $LogDisk){$HDInfo4 += "{0:N2}" -f ($disk.FreeSpace/1073741824)}
        $HD4.ItemsSource = $HDInfo4
        $HDInfo5 = @()
        ForEach ($disk in $LogDisk){$HDInfo5 += "{0:N0}" -f (100.0*$disk.FreeSpace/$disk.Size)}
        $HD5.ItemsSource = $HDInfo5
        $HDInfo6 = @()
        ForEach ($disk in $LogDisk){$HDInfo6 += if (100.0 * $disk.FreeSpace / $disk.Size -le $levelAlarm) {"Alarm !!!"} elseif (100.0 * $disk.FreeSpace / $disk.Size -le $levelWarn) {"Warning !!!"} else {"OK"}}
        $HD6.ItemsSource = $HDInfo6
        $IPInfo1 = @()
        foreach ($ip in (Get-WmiObject -ComputerName $MachineName.Text Win32_NetworkAdapterConfiguration)) {$IPInfo1 += if ($ip.IPAddress -ne $null) {$ip.IPAddress[0]}}
        $IP1.ItemsSource = $IPInfo1
        $IPInfo2 = @()
        foreach ($ip in (Get-WmiObject -ComputerName $MachineName.Text Win32_NetworkAdapterConfiguration)) {$IPInfo2 += if ($ip.IPAddress -ne $null) {$ip.Description}}
        $IP2.ItemsSource = $IPInfo2
        $IPInfo3 = @()
        foreach ($ip in (Get-WmiObject -ComputerName $MachineName.Text Win32_NetworkAdapterConfiguration)) {$IPInfo3 += if ($ip.IPAddress -ne $null) {$ip.DHCPEnabled}}
        $IP3.ItemsSource = $IPInfo3
        $LastBoot.Text = $OS.ConvertToDateTime($OS.LastBootupTime)
        $Uptime.Text = "Uptime:  " + (($dateTime - ($OS.ConvertToDateTime($OS.LastBootupTime))).Days) + " Days, " + (($dateTime - ($OS.ConvertToDateTime($OS.LastBootupTime))).Hours) + " Hours, " + (($dateTime - ($OS.ConvertToDateTime($OS.LastBootupTime))).Minutes) + " Minutes"
        }
    New-Button "Collect Info" -Width 75 -HorizontalAlignment Right -Column 2 -On_Click {

        #Set variables used if "Collect Info" button clicked
        [float] $levelWarn  = 20.0;  # Warn-level in percent. 
        [float] $levelAlarm = 10.0;  # Alarm-level in percent. 
        $BIOS = Get-WmiObject -Class Win32_BIOS -ComputerName $MachineName.Text
        $OS = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $MachineName.Text
        $CompSys = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $MachineName.Text
        $CPU = Get-WmiObject -Class Win32_Processor -ComputerName $MachineName.Text
        $LogDisk = Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType = 3" -ComputerName $MachineName.Text
        $RAM1 = Get-WmiObject -Class Win32_PhysicalMemoryArray -ComputerName $MachineName.Text
        $RAM2 = Get-WmiObject -Class Win32_PhysicalMemory -ComputerName $MachineName.Text
        $dateTime = Get-Date

        #Fill textboxes if "Collect Info" button clicked
        $ComputerName.Text = $BIOS.PSComputerName
        $ComputerDomain.Text = $CompSys.Domain
        $ComputerDescription.Text = $OS.Description
        $Manufacturer.Text = $BIOS.Manufacturer
        $Model.Text = $CompSys.Model
        $SerialNum.Text = $BIOS.SerialNumber
        $BIOSVer.Text = $BIOS.smBIOSBIOSVersion
        $OperatingSystem.Text = $OS.Caption, $OS.CSDVersion
        $Mem.Text = "{0:N0} GB" -f ($CompSys.TotalPhysicalMemory / 1GB) + " | " + ($RAM2.DeviceLocator).Count + " Modules Installed | " + $RAM1.MemoryDevices + " Total Slots | " + ($RAM1.MemoryDevices-($RAM2.DeviceLocator).Count) + " Empty Slots"
        $CPUDesc.Text = $CPU.NumberOfCores, "Cores @", "{0:N1} GHz" -f ($CPU.MaxClockSpeed / 1024) 
        $HDInfo1 = @()
        ForEach ($disk in $LogDisk){$HDInfo1 += $disk.DeviceID}
        $HD1.ItemsSource = $HDInfo1
        $HDInfo2 = @()
        ForEach ($disk in $LogDisk){$HDInfo2 += $disk.VolumeName}
        $HD2.ItemsSource = $HDInfo2
        $HDInfo3 = @()
        ForEach ($disk in $LogDisk){$HDInfo3 += "{0:N2}" -f ($disk.Size/1073741824)}
        $HD3.ItemsSource = $HDInfo3
        $HDInfo4 = @()
        ForEach ($disk in $LogDisk){$HDInfo4 += "{0:N2}" -f ($disk.FreeSpace/1073741824)}
        $HD4.ItemsSource = $HDInfo4
        $HDInfo5 = @()
        ForEach ($disk in $LogDisk){$HDInfo5 += "{0:N0}" -f (100.0*$disk.FreeSpace/$disk.Size)}
        $HD5.ItemsSource = $HDInfo5
        $HDInfo6 = @()
        ForEach ($disk in $LogDisk){$HDInfo6 += if (100.0 * $disk.FreeSpace / $disk.Size -le $levelAlarm) {"Alarm !!!"} elseif (100.0 * $disk.FreeSpace / $disk.Size -le $levelWarn) {"Warning !!!"} else {"OK"}}
        $HD6.ItemsSource = $HDInfo6
        $IPInfo1 = @()
        foreach ($ip in (Get-WmiObject -ComputerName $MachineName.Text Win32_NetworkAdapterConfiguration)) {$IPInfo1 += if ($ip.IPAddress -ne $null) {$ip.IPAddress[0]}}
        $IP1.ItemsSource = $IPInfo1
        $IPInfo2 = @()
        foreach ($ip in (Get-WmiObject -ComputerName $MachineName.Text Win32_NetworkAdapterConfiguration)) {$IPInfo2 += if ($ip.IPAddress -ne $null) {$ip.Description}}
        $IP2.ItemsSource = $IPInfo2
        $IPInfo3 = @()
        foreach ($ip in (Get-WmiObject -ComputerName $MachineName.Text Win32_NetworkAdapterConfiguration)) {$IPInfo3 += if ($ip.IPAddress -ne $null) {$ip.DHCPEnabled}}
        $IP3.ItemsSource = $IPInfo3
        $LastBoot.Text = $OS.ConvertToDateTime($OS.LastBootupTime)
        $Uptime.Text = "Uptime:  " + (($dateTime - ($OS.ConvertToDateTime($OS.LastBootupTime))).Days) + " Days, " + (($dateTime - ($OS.ConvertToDateTime($OS.LastBootupTime))).Hours) + " Hours, " + (($dateTime - ($OS.ConvertToDateTime($OS.LastBootupTime))).Minutes) + " Minutes"
        }
    New-Label " " -Row 1 -ColumnSpan 3
    }
    #Computer Name | Domain | Description
    Grid -Columns 3 -Rows 2 {
        New-Label "Computer Name" -FontWeight Bold
        New-Label "Domain" -FontWeight Bold -Column 1
        New-Label "Description" -FontWeight Bold -Column 2
        New-TextBox -Name ComputerName -Margin 2 -Row 1
        New-TextBox -Name ComputerDomain -Margin 2 -Row 1 -Column 1
        New-TextBox -Name ComputerDescription -Margin 2 -Row 1 -Column 2
    }
 
    #Manufacturer | Model | Serial Number | BIOS Version
    Grid -Columns 4 -Rows 2 {
        New-Label "Manufacturer" -FontWeight Bold
        New-Label "Model" -FontWeight Bold -Column 1
        New-Label "Serial Number" -FontWeight Bold -Column 2
        New-Label "BIOS Version" -FontWeight Bold -Column 3
        New-TextBox -Name Manufacturer -Margin 2 -Row 1
        New-TextBox -Name Model -Margin 2 -Row 1 -Column 1
        New-TextBox -Name SerialNum -Margin 2 -Row 1 -Column 2
        New-TextBox -Name BIOSVer -Margin 2 -Row 1 -Column 3
    }

    #Operating System 
    New-Label "Operating System" -FontWeight Bold 
    New-TextBox -Name OperatingSystem -Margin 2
 
    #Processor & Memory
    Grid -Columns 2 -Rows 2 {
        New-Label "Processor" -FontWeight Bold
        New-Label "Memory (RAM)" -FontWeight Bold -Column 1
        New-TextBox -Name CPUDesc -Margin 2 -Row 1
        New-TextBox -Name Mem -Margin 2 -Row 1 -Column 1
    }
 
    #HD Info
    Grid -Columns 6 -Rows 2 {
        New-Label "Drive" -FontWeight Bold
        New-Label "Label" -FontWeight Bold -Column 1
        New-Label "Total Size (GB)" -FontWeight Bold -Column 2
        New-Label "Free Space (GB)" -FontWeight Bold -Column 3
        New-Label "% Free" -FontWeight Bold -Column 4
        New-Label "Status" -FontWeight Bold -Column 5
        New-ListView -Name HD1 -ItemsSource $HDInfo1 -Row 1
        New-ListView -Name HD2 -ItemsSource $HDInfo2 -Row 1 -Column 1
        New-ListView -Name HD3 -ItemsSource $HDInfo3 -Row 1 -Column 2 -HorizontalContentAlignment Right
        New-ListView -Name HD4 -ItemsSource $HDInfo4 -Row 1 -Column 3 -HorizontalContentAlignment Right
        New-ListView -Name HD5 -ItemsSource $HDInfo5 -Row 1 -Column 4 -HorizontalContentAlignment Right
        New-ListView -Name HD6 -ItemsSource $HDInfo6 -Row 1 -Column 5
    }


    #IP Address
    Grid -Columns 3 -Rows 2 {
        New-Label "IPv4 Address" -FontWeight Bold 
        New-Label "Interface Description" -FontWeight Bold -Column 1 
        New-Label "DHCP?" -FontWeight Bold -Column 2
        New-ListView -ItemsSource IPInfo1 -Name IP1 -Row 1
        New-ListView -ItemsSource IPInfo2 -Name IP2 -Row 1 -Column 1
        New-ListView -ItemsSource IPInfo3 -Name IP3 -Row 1 -Column 2
    }
    
    #Last Boot Time
    Grid -Columns 2 -Rows 2 {
        New-Label "Last Boot Time" -FontWeight Bold 
        New-Label "Uptime" -FontWeight Bold -Column 1 
        New-TextBox -Name LastBoot -Margin 2 -Row 1
        New-TextBox -Name Uptime -Margin 2 -Row 1 -Column 1
    }

} -Show
