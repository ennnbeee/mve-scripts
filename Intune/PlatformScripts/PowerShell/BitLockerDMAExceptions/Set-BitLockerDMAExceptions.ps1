# Allow for silent BitLocker Encryption
# https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/oem-bitlocker#un-allowed-dma-capable-busdevices-detected


# Path required for allowing DMA exceptions
$regPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\DmaSecurity\AllowedBuses'
$dmaDevices = @()

$devicesLenovo = @('20UACTO1WW', '20KG0005AU')
$devicesDell = @('Latitude 7320','Latitude 5320')
$devicesHP = @('HP EliteBook 8540p')

Try {

    $deviceModel = (Get-WmiObject -Class:Win32_ComputerSystem).Model

    if ($deviceModel -in $devicesDell) {
        $dmaDevices += [pscustomobject]@{name = 'Intel(R) 300 Series Chipset Family LPC Controller (HM370) - A30D'; value = 'PCI\VEN_8086&DEV_A30D'}
        $dmaDevices += [pscustomobject]@{name = 'Intel(R) PCI Express Root Port #13 - A334'; value = 'PCI\VEN_8086&DEV_A334'}
        $dmaDevices += [pscustomobject]@{name = 'Intel(R) PCI Express Root Port #16 - A337'; value = 'PCI\VEN_8086&DEV_A337'}
        $dmaDevices += [pscustomobject]@{name = 'Intel(R) PCI Express Root Port #20 - A343'; value = 'PCI\VEN_8086&DEV_A343'}
    }
    elseif ($deviceModel -in $devicesLenovo) {
        $dmaDevices += [pscustomobject]@{name = 'PCI Express Downstream Switch Port'; value = 'PCI\VEN_8086&DEV_15C0'}
    }
    elseif ($deviceModel -in $devicesHP ){
        $dmaDevices += [pscustomobject]@{name = 'Intel(R) PCI Express Root Port #9 - A330'; value = 'PCI\VEN_8086&DEV_A330'}
        $dmaDevices += [pscustomobject]@{name = 'Intel(R) Xeon(R) E3 - 1200/1500 v5/6th Gen Intel(R) Core(TM) PCIe Controller (x16) - 1901'; value = 'PCI\VEN_8086&DEV_1901'}
        $dmaDevices += [pscustomobject]@{name = 'Intel(R) PCI Express Root Port #15 - A336'; value = 'PCI\VEN_8086&DEV_A336'}
    }

    foreach ($dmaDevice in $dmaDevices) {
        New-ItemProperty -Path $regPath -Name $dmaDevice.name -Value $dmaDevice.value -PropertyType String -Force
    }

}
Catch {
    Write-Error $_.ErrorDetails
}