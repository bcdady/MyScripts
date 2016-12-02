#requires -version 3.0
function Set-EnvVariable {
<#
  .SYNOPSIS
    Sets the value of an environment variable
  .DESCRIPTION
    This function will set the value of an environment variable.  The default behavior is to overwrite the existing value.  The concatenate switch will append the new value to the existing value.
  .EXAMPLE
    Set-EnvVariable -Name Path -Value C:\git -Concatenate

    Adds, ";c:\git" to the path variable
  .EXAMPLE
    (get-childitem c:\ -recurse -filter git.exe -force).fullname | split-path | Foreach {Set-EnvVariable -Name -value $_}

    Adds all folders containing git.exe to the Path
  .EXAMPLE
    Set-EnvVariable -Name Path -Value $NewPath

    Set the Path to the content of $NewPath
  .NOTES
    Written by Jason Morgan
    Created on 6/15/2014
    Last Modified 6/2/2014
.LINK
https://gallery.technet.microsoft.com/Set-Environment-Variable-0e7492a3
#>
    [cmdletbinding(SupportsShouldProcess=$true,
    ConfirmImpact='high',
    DefaultParameterSetName='Default')]
    Param (
        # Set the value of the environment variable
        [Parameter(Mandatory,
            ValueFromPipeline,
            ParameterSetName='Default')]
        [Parameter(ParameterSetName='Concat')]
        [string]$Value,
    
        # Enter the name of the Environment variable you want modified
        [Parameter(Mandatory,
            ValueFromPipelineByPropertyName,
            ParameterSetName='Default')]
        [Parameter(ParameterSetName='Concat')]
        [validatescript({$_ -in ((Get-ChildItem -path env:\).name)})]
        [string]$Name,
    
        # Enter the type, user or machine
        [Parameter(ParameterSetName='Default')]
        [Parameter(ParameterSetName='Concat')]
        [ValidateSet('Machine','User')]
        [string]$Class = 'Machine',

        # Enter separator character, defaults to ';'
        [Parameter(ParameterSetName='Concat')]
        [ValidateLength(0,1)]
        [string]$Separator = ';',

        # Set to append to current value
        [Parameter(ParameterSetName='Concat')]
        [switch]$Concatenate
    )
    begin {}
    process {
        if ($PSCmdlet.ShouldProcess("$Name","Set Environment Variable to $Value")) {
            switch ($Concatenate) {
                $true  {
                    $CurrentValue = [Environment]::GetEnvironmentVariable($Name, $Class)
                    [Environment]::SetEnvironmentVariable($Name, ($CurrentValue + $Separator + $Value) , $Class)
                 }
                $false  {
                    [Environment]::SetEnvironmentVariable($Name, $Value, $Class)
                  }
              }
          }
      }
    end {}
}

#Find full path to bin\git.exe and add it to the PATH variable
Set-EnvVariable -Name PATH -Value (Get-ChildItem -Path $env:LOCALAPPDATA\git* -Filter git.exe -Recurse | Select-Object -First 1 | Select-Object -Property FullName).FullName -Concatenate -WhatIf
