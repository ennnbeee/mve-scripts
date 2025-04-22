[CmdletBinding(DefaultParameterSetName = 'Default')]

param(

    [Parameter(Mandatory = $false)]
    [ValidateSet('W10-22H2', 'W11-23H2', 'W11-24H2')]
    [String]$osVersion = 'W11-24H2',

    [Parameter()][String]
    $computerName = $env:COMPUTERNAME

)

#region variables
$serialNumber = -join ((65..90) + (97..122) + (48..57) | Get-Random -Count 16 | ForEach-Object { [char]$_ })
$rootPath = 'C:\Source\VMs'
$exportPath = "$rootPath\Exports"
$vmPath = "$rootPath\Lab"

switch ($osVersion) {
    'W10-22H2' {
        $vmName = "Lab-W10-22H2-$serialNumber"
        $vmImportPath = "$exportPath\Template_W10_22H2_Pro"
    }
    'W11-23H2' {
        $vmName = "Lab-W11-23H2-$serialNumber"
        $vmImportPath = "$exportPath\Template_W11_23H2_Pro"
    }
    'W11-24H2' {
        $vmName = "Lab-W11-24H2-$serialNumber"
        $vmImportPath = "$exportPath\Template_W11_24H2_Pro"
    }
}
#endregion variables

#region functions
function Set-VMAdvancedSettings {
    # uncomment this line, the second line, and the last line to use as a profile or dot-sourced function
    # uncomment this line, the first line, and the last line to use as a profile or dot-sourced function
    <#
       .SYNOPSIS
           Changes the settings for Hyper-V guests that are not available through GUI tools.
           If you do not specify any parameters to be changed, the script will re-apply the settings that the virtual machine already has.
       .DESCRIPTION
           Changes the settings for Hyper-V guests that are not available through GUI tools.
           If you do not specify any parameters to be changed, the script will re-apply the settings that the virtual machine already has.
           If the virtual machine is running, this script will attempt to shut it down prior to the operation. Once the replacement is complete, the virtual machine will be turned back on.
       src: https://www.altaro.com/hyper-v/powershell-script-change-advanced-settings-hyper-v-virtual-machines/
       .PARAMETER VM
           The name or virtual machine object of the virtual machine whose BIOSGUID is to be changed. Will accept a string, output from Get-VM, or a WMI instance of class Msvm_ComputerSystem.
       .PARAMETER ComputerName
           The name of the Hyper-V host that owns the target VM. Only used if VM is a string.
       .PARAMETER NewBIOSGUID
           The new GUID to assign to the virtual machine. Cannot be used with AutoGenBIOSGUID.
        .PARAMETER AutoGenBIOSGUID
             Automatically generate a new BIOS GUID for the VM. Cannot be used with NewBIOSGUID.
        .PARAMETER BaseboardSerialNumber
             New value for the VM's baseboard serial number.
        .PARAMETER BIOSSerialNumber
             New value for the VM's BIOS serial number.
        .PARAMETER ChassisAssetTag
             New value for the VM's chassis asset tag.
        .PARAMETER ChassisSerialNumber
             New value for the VM's chassis serial number.
       .PARAMETER ComputerName
           The Hyper-V host that owns the virtual machine to be modified.
       .PARAMETER Timeout
           Number of seconds to wait when shutting down the guest before assuming the shutdown failed and ending the script.
           Default is 300 (5 minutes).
           If the virtual machine is off, this parameter has no effect.
       .PARAMETER Force
           Suppresses prompts. If this parameter is not used, you will be prompted to shut down the virtual machine if it is running and you will be prompted to replace the BIOSGUID.
           Force can shut down a running virtual machine. It cannot affect a virtual machine that is saved or paused.
       .PARAMETER WhatIf
           Performs normal WhatIf operations by displaying the change that would be made. However, the new BIOSGUID is automatically generated on each run. The one that WhatIf displays will not be used.
       .NOTES
           Version 1.3
           November 13th, 2024
           Author: Martin Bijl
           * see https://learn.microsoft.com/en-us/powershell/scripting/learn/ps101/07-working-with-wmi?view=powershell-7.4
           * Update to Powershell 7 (on Windows)
           * Use CIM instead of WMI

           Version 1.2
           July 25th, 2018
           Author: Eric Siron

           Version 1.2:
           * Multiple non-impacting infrastructure improvements
           * Fixed operating against remote systems
           * Fixed "Force" behavior

           Version 1.1: Fixed incorrect verbose outputs. No functionality changes.
       .EXAMPLE
           Set-VMAdvancedSettings -VM svtest -AutoGenBIOSGUID

           Replaces the BIOS GUID on the virtual machine named svtest with an automatically-generated ID.

       .EXAMPLE
           Set-VMAdvancedSettings svtest -AutoGenBIOSGUID

           Exactly the same as example 1; uses positional parameter for the virtual machine.

       .EXAMPLE
           Get-VM svtest | Set-VMAdvancedSettings -AutoGenBIOSGUID

           Exactly the same as example 1 and 2; uses the pipeline.

       .EXAMPLE
           Set-VMAdvancedSettings -AutoGenBIOSGUID -Force

           Exactly the same as examples 1, 2, and 3; prompts suppressed.

       .EXAMPLE
           Set-VMAdvancedSettings -VM svtest -NewBIOSGUID $Guid

           Replaces the BIOS GUID of svtest with the supplied ID. These IDs can be generated with [System.Guid]::NewGuid(). You can also supply any value that can be parsed to a GUID (ex: C0AB8999-A69A-44B7-B6D6-81457E6EC66A }.

       .EXAMPLE
           Set-VMAdvancedSettings -VM svtest -NewBIOSGUID $Guid -BaseBoardSerialNumber '42' -BIOSSerialNumber '42' -ChassisAssetTag '42' -ChassisSerialNumber '42'

           Modifies all settings that this function can affect.

       .EXAMPLE
           Set-VMAdvancedSettings -VM svtest -AutoGenBIOSGUID -WhatIf

           Shows HOW the BIOS GUID will be changed, but the displayed GUID will NOT be recycled if you run it again without WhatIf. TIP: Use this to view the current BIOS GUID without changing it.

       .EXAMPLE
           Set-VMAdvancedSettings -VM svtest -NewBIOSGUID $Guid -BaseBoardSerialNumber '42' -BIOSSerialNumber '42' -ChassisAssetTag '42' -ChassisSerialNumber '42' -WhatIf

           Shows what would be changed without making any changes. TIP: Use this to view the current settings without changing them.
       #>
    #requires -Version 4

    [CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High', DefaultParameterSetName = 'ManualBIOSGUID')]
    param
    (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 1)][PSObject]$VM,
        [Parameter()][String]$ComputerName = $env:COMPUTERNAME,
        [Parameter(ParameterSetName = 'ManualBIOSGUID')][Object]$NewBIOSGUID,
        [Parameter(ParameterSetName = 'AutoBIOSGUID')][Switch]$AutoGenBIOSGUID,
        [Parameter()][String]$BaseBoardSerialNumber,
        [Parameter()][String]$BIOSSerialNumber,
        [Parameter()][String]$ChassisAssetTag,
        [Parameter()][String]$ChassisSerialNumber,
        [Parameter()][UInt32]$Timeout = 300,
        [Parameter()][Switch]$Force
    )

    begin {
        function Update-VMSetting {
            param
            (
                [Parameter(Mandatory = $true)][Microsoft.Management.Infrastructure.CimInstance]$VMSettings,
                [Parameter(Mandatory = $true)][String]$PropertyName,
                [Parameter(Mandatory = $true)][String]$NewPropertyValue,
                [Parameter(Mandatory = $true)][String]$PropertyDisplayName,
                [Parameter(Mandatory = $true)][System.Text.StringBuilder]$ConfirmText
            )
            $Message = 'Set "{0}" from {1} to {2}' -f $PropertyName, $VMSettings[($PropertyName)], $NewPropertyValue
            Write-Verbose -Message $Message
            $OutNull = $ConfirmText.AppendLine($Message)
            $CurrentSettingsData.cimInstanceProperties[$PropertyName].Value = $NewPropertyValue
            $OriginalValue = $CurrentSettingsData[($PropertyName)]
        }
    }
    process {
        $ConfirmText = New-Object System.Text.StringBuilder
        $VMObject = $null
        Write-Verbose -Message 'Validating input...'
        $VMName = ''
        $InputType = $VM.GetType()
        if ($InputType.FullName -eq 'System.String') {
            $VMName = $VM
        }
        elseif ($InputType.FullName -eq 'Microsoft.HyperV.PowerShell.VirtualMachine') {
            $VMName = $VM.Name
            $ComputerName = $VM.ComputerName
        }
        elseif ($InputType.FullName -eq 'System.Management.ManagementObject') {
            $VMObject = $VM
        }
        else {
            Write-Error -Message 'You must supply a virtual machine name, a virtual machine object from the Hyper-V module, or an Msvm_ComputerSystem WMI object.'
            exit 1
        }

        if ($null -ne $NewBIOSGUID) {
            try {
                $NewBIOSGUID = [System.Guid]::Parse($NewBIOSGUID)
            }
            catch {
                Write-Error -Message 'Provided GUID cannot be parsed. Supply a valid GUID or use the AutoGenBIOSGUID parameter to allow an ID to be automatically generated.'
                exit 1
            }
        }

        $CimSession = New-CimSession
        if ($env:COMPUTERNAME -ne $ComputerName) {
            # if you specify $ComputerName then make sure target computer (even if localhost) have WinRM/WSMan properly configured, check: https://learn.microsoft.com/en-us/powershell/module/cimcmdlets/get-ciminstance?view=powershell-7.4#description
            $CimSession = New-CimSession -ComputerName $ComputerName
        }

        Write-Verbose -Message ('Establishing CIM connection to Virtual Machine Management Service on {0}...' -f $ComputerName)
        $VMMS = Get-CimInstance -CimSession $CimSession -Namespace 'root\virtualization\v2' -Class 'Msvm_VirtualSystemManagementService' -ErrorAction Stop

        Write-Verbose -Message 'Acquiring an empty parameter object for the ModifySystemSettings function...'
        $ModifySystemSettingsParams = $VMMS.CimClass.CimClassMethods['ModifySystemSettings']

        Write-Verbose -Message ('Establishing WMI connection to virtual machine {0}' -f $VMName)
        if ($null -eq $VMObject) {
            $VMObject = Get-CimInstance -CimSession $CimSession -Namespace 'root\virtualization\v2' -Class 'Msvm_ComputerSystem' -Filter ('ElementName = "{0}"' -f $VMName) -ErrorAction Stop
        }
        if ($null -eq $VMObject) {
            Write-Error -Message ('Virtual machine {0} not found on computer {1}' -f $VMName, $ComputerName)
            exit 1
        }
        Write-Verbose -Message ('Verifying that {0} is off...' -f $VMName)
        $OriginalState = $VMObject.EnabledState
        if ($OriginalState -ne 3) {
            if ($OriginalState -eq 2 -and ($Force.ToBool() -or $PSCmdlet.ShouldProcess($VMName, 'Shut down'))) {
                Write-Verbose -Message 'Initiating shutdown...'

                # Note: Stop-VM could be a simpler option
                $VirtualizationComponent = $VMObject | Get-CimAssociatedInstance -Namespace 'root/virtualization/v2'
                $ShutdownComponent = $VirtualizationComponent | Where-Object { $_.cimclass.cimclassname -eq 'Msvm_ShutdownComponent' }
                Invoke-CimMethod $shutdown -MethodName InitiateShutdown -Arguments @{ 'Force' = $true; 'Reason' = 'Change BIOSGUID' }

                # the InitiateShutdown function completes as soon as the guest's integration services respond; it does not wait for the power state change to complete
                Write-Verbose -Message ('Waiting for virtual machine {0} to shut down...' -f $VMName)
                $TimeoutCounterStarted = [datetime]::Now
                $TimeoutExpiration = [datetime]::Now + [timespan]::FromSeconds($Timeout)
                while ($VMObject.EnabledState -ne 3) {
                    $ElapsedPercent = [UInt32]((([datetime]::Now - $TimeoutCounterStarted).TotalSeconds / $Timeout) * 100)
                    if ($ElapsedPercent -ge 100) {
                        Write-Error -Message ('Timeout waiting for virtual machine {0} to shut down' -f $VMName)
                        exit 1
                    }
                    else {
                        Write-Progress -Activity ('Waiting for virtual machine {0} on {1} to stop' -f $VMName, $ComputerName) -Status ('{0}% timeout expiration' -f ($ElapsedPercent)) -PercentComplete $ElapsedPercent
                        Start-Sleep -Milliseconds 250
                        $VMObject = $VMObject | Get-CimInstance
                    }
                }
            }
            elseif ($OriginalState -ne 2) {
                Write-Error -Message ('Virtual machine must be turned off to change advanced settings. It is not in a state this script can work with.' -f $VMName)
                exit 1
            }
        }
        Write-Verbose -Message ('Retrieving all current settings for virtual machine {0}' -f $VMName)
        $CurrentSettingsDataCollection = $VMObject | Get-CimAssociatedInstance -Namespace 'root/virtualization/v2' | Where-Object { $_.cimclass.cimclassname -eq 'Msvm_VirtualSystemSettingData' }
        Write-Verbose -Message 'Extracting the settings data object from the settings data collection object...'
        $CurrentSettingsData = $null
        foreach ($SettingsObject in $CurrentSettingsDataCollection) {
            if ($VMObject.Name -eq $SettingsObject.ConfigurationID) {
                $CurrentSettingsData = [Microsoft.Management.Infrastructure.CimInstance]($SettingsObject)
            }
        }

        if ($AutoGenBIOSGUID -or $NewBIOSGUID) {
            if ($AutoGenBIOSGUID) {
                $NewBIOSGUID = [System.Guid]::NewGuid().ToString()
            }
            Update-VMSetting -VMSettings $CurrentSettingsData -PropertyName 'BIOSGUID' -NewPropertyValue (('{{{0}}}' -f $NewBIOSGUID).ToUpper()) -PropertyDisplayName 'BIOSGUID' -ConfirmText $ConfirmText
        }
        if ($BaseBoardSerialNumber) {
            Update-VMSetting -VMSettings $CurrentSettingsData -PropertyName 'BaseboardSerialNumber' -NewPropertyValue $BaseBoardSerialNumber -PropertyDisplayName 'baseboard serial number' -ConfirmText $ConfirmText
        }
        if ($BIOSSerialNumber) {
            Update-VMSetting -VMSettings $CurrentSettingsData -PropertyName 'BIOSSerialNumber' -NewPropertyValue $BIOSSerialNumber -PropertyDisplayName 'BIOS serial number' -ConfirmText $ConfirmText
        }
        if ($ChassisAssetTag) {
            Update-VMSetting -VMSettings $CurrentSettingsData -PropertyName 'ChassisAssetTag' -NewPropertyValue $ChassisAssetTag -PropertyDisplayName 'chassis asset tag' -ConfirmText $ConfirmText
        }
        if ($ChassisSerialNumber) {
            Update-VMSetting -VMSettings $CurrentSettingsData -PropertyName 'ChassisSerialNumber' -NewPropertyValue $ChassisSerialNumber -PropertyDisplayName 'chassis serial number' -ConfirmText $ConfirmText
        }

        Write-Verbose -Message 'Assigning modified data object as parameter for ModifySystemSettings function...'
        if ($Force.ToBool() -or $PSCmdlet.ShouldProcess($VMName, $ConfirmText.ToString())) {
            Write-Verbose -Message ('Instructing Virtual Machine Management Service to modify settings for virtual machine {0}' -f $VMName)

            # the ModifySystemSettings uses a special format called "MOF".
            $serializer = [Microsoft.Management.Infrastructure.Serialization.CimSerializer]::Create()
            $SystemSettings = [System.Text.Encoding]::Unicode.GetString($serializer.Serialize($CurrentSettingsData, [Microsoft.Management.Infrastructure.Serialization.InstanceSerializationOptions]::None))

            $result = Invoke-CimMethod $VMMS -MethodName 'ModifySystemSettings' -Arguments @{
                SystemSettings = $SystemSettings
            }
        }
        $VMObject = $VMObject | Get-CimInstance
        if ($OriginalState -ne $VMObject.EnabledState) {
            Write-Verbose -Message ('Returning {0} to its prior running state.' -f $VMName)
            $result = Invoke-CimMethod $VMObject -MethodName 'RequestStateChange' -Arguments @{
                RequestedState = $OriginalState
            }
        }
    }
}
#endregion functions

#region elevation
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal $identity

if (!$principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Host -ForegroundColor Red 'Error:  Must run elevated: run as administrator'
    Write-Host 'No commands completed'
    return
}
#endregion elevation

#region import VM
$vmImportFile = (Get-ChildItem -Path $vmImportPath -Filter *.vmcx -Recurse).FullName

$importedVM = Import-VM -ComputerName $computerName -GenerateNewId -Path $vmImportFile -VirtualMachinePath $vmPath -VhdDestinationPath $vmPath -Copy

#region modify VM settings
$virtualMachine = Get-VM -Name $importedVM.Name
Set-VMAdvancedSettings -VM $virtualMachine -AutoGenBIOSGUID -Force -BaseBoardSerialNumber $serialNumber -BIOSSerialNumber $serialNumber -ChassisAssetTag $serialNumber -ChassisSerialNumber $serialNumber
#endregion modify VM settings

Rename-VM -ComputerName $computerName -Name $importedVM.Name -NewName $vmName

if ($osVersion -like 'W10*') {
    $guardianOwner = Get-HgsGuardian UntrustedGuardian
    $keyProtector = New-HgsKeyProtector -Owner $guardianOwner -AllowUntrustedRoot

    Set-VMKeyProtector -VMName $vmName -KeyProtector $keyProtector.RawData
    Enable-VMTPM -ComputerName $computerName -VMName $vmName
}

$vhdxDisk = Get-VM -ComputerName $computerName -Name $vmName | Get-VMHardDiskDrive
$vhdxFile = Rename-Item $vhdxDisk.Path -NewName "$($vmName).vhdx" -PassThru

Set-VMHardDiskDrive -VMName $vmName -Path $($vhdxFile.FullName) -ControllerType $($vhdxDisk.ControllerType)
Get-VMDvdDrive -VMName $vmName | Set-VMDvdDrive -Path $null
#endregion import VM

