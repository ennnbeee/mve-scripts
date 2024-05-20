# Variables
$fwClient = '' # Third-party Firewall Client Name
$avClient = '' # Third-party Antivirus Client Name
$cyberEssentials = New-Object -TypeName PSObject

# Guest Account
$guestAccount = Get-WmiObject Win32_UserAccount | Where-Object SID -Like '*501' | Select-Object Domain, Name, Disabled
$guestAccountStatus = switch ($guestAccount.Disabled) {
    'True' { 'True' }
    'False' { 'False' }
}
$cyberEssentials | Add-Member -MemberType NoteProperty -Name 'Built-in Guest account disabled' -Value $guestAccountStatus

# AutoRun/Autoplay
Try {
    $autorunState = Get-ItemPropertyValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\' -Name 'NoDriveTypeAutoRun'
    if ($autorunState -eq 255) {
        $autorunStatus = 'True'
    }
    else {
        $autorunStatus = 'False'
    }
}
Catch {
    $autorunStatus = 'False'
}

$cyberEssentials | Add-Member -MemberType NoteProperty -Name 'Autoplay disabled' -Value $autorunStatus

# Antivirus
if ($avClient) {
    $avProduct = Get-WmiObject -Namespace 'root\SecurityCenter2' -Class AntiVirusProduct | Where-Object { $_.displayName -eq $avClient } | Select-Object -First 1
    if ($avProduct) {
        [string]$avProductState = [System.Convert]::ToString($avProduct.productState, 16).PadLeft(6, '0')
        $avRealTimeProtection = $avProductState.Substring(2, 2)
        $avDefinitions = $avProductState.Substring(4, 2)

        $avRealTimeProtectionStatus = switch ($avRealTimeProtection) {
            '00' { 'False' }
            '01' { 'Expired' }
            '10' { 'True' }
            '11' { 'Snoozed' }
            default { 'Unknown' }
        }

        $avDefinitionStatus = switch ($avDefinitions) {
            '00' { 'True' }
            '10' { 'False' }
            default { 'Unknown' }
        }

        $cyberEssentials | Add-Member -MemberType NoteProperty -Name "$avClient real time protection enabled" -Value $avRealTimeProtectionStatus
        $cyberEssentials | Add-Member -MemberType NoteProperty -Name "$avClient definitions up-to-date" -Value $avDefinitionStatus
    }
    else {
        $cyberEssentials | Add-Member -MemberType NoteProperty -Name "$avClient real time protection enabled" -Value "Error: $avClient not product found"
        $cyberEssentials | Add-Member -MemberType NoteProperty -Name "$avClient definitions up-to-date" -Value "Error: $avClient not product found"
    }

}
else {
    # Defender
    $defenderStatus = Get-MpComputerStatus

    $defenderAM = $defenderStatus.AMServiceEnabled
    $defenderAS = $defenderStatus.AntispywareEnabled
    $defenderAV = $defenderStatus.AntivirusEnabled
    if ($defenderStatus.AntivirusSignatureAge -le 1) {
        $defenderSig = 'True'
    }
    else {
        $defenderSig = 'False'
    }

    $cyberEssentials | Add-Member -MemberType NoteProperty -Name 'Defender antimalware service enabled' -Value $defenderAM
    $cyberEssentials | Add-Member -MemberType NoteProperty -Name 'Defender antispyware enabled' -Value $defenderAS
    $cyberEssentials | Add-Member -MemberType NoteProperty -Name 'Defender antivirus enabled' -Value $defenderAV
    $cyberEssentials | Add-Member -MemberType NoteProperty -Name 'Defender signatures up-to-date' -Value $defenderSig

}

# Firewall
if ($fwClient) {
    $fwProduct = Get-WmiObject -Namespace root\securityCenter2 -Class FirewallProduct | Where-Object { $_.displayName -eq $fwClient } | Select-Object -First 1
    if ($fwProduct) {

        [string]$fwProductState = [System.Convert]::ToString($fwProduct.ProductState, 16).padleft(6, '0')
        $fwProtection = $fwProductState.substring(2, 2)

        $fwProtectionStatus = switch ($fwProtection) {
            '00' { 'False' }
            '10' { 'True' }
            default { 'Unknown' }
        }

        $cyberEssentials | Add-Member -MemberType NoteProperty -Name "$fwClient firewall enabled" -Value $fwProtectionStatus
    }
    else {
        $cyberEssentials | Add-Member -MemberType NoteProperty -Name "$fwClient firewall enabled" -Value "Error: $fwClient product not found"
    }
}
else {
    # Defender Firewall Status
    $fwProfiles = Get-NetFirewallProfile
    foreach ($fwProfile in $fwProfiles) {

        $fwStatus = $fwProfile.Enabled
        $cyberEssentials | Add-Member -MemberType NoteProperty -Name "Windows Defender $($fwProfile.name) firewall enabled" -Value $fwStatus

    }
}

# Windows Updates
$updateTime = Get-Item @(
    "${env:windir}\System32\ntoskrnl.exe",
    "${env:windir}\System32\win32k.sys",
    "${env:windir}\System32\win32kbase.sys",
    "${env:windir}\System32\win32kfull.sys",
    "${env:windir}\System32\ntdll.dll",
    "${env:windir}\System32\USER32.dll",
    "${env:windir}\System32\KERNEL32.dll",
    "${env:windir}\System32\HAL.dll"
) | Measure-Object -Maximum LastWriteTimeUtc | Select-Object -ExpandProperty Maximum

$todayTime = Get-Date
If ((New-TimeSpan -Start $updateTime -End $todayTime).Days -le 31) {
    $updateAge = 'True'
}
else {
    $updateAge = 'False'
}
$cyberEssentials | Add-Member -MemberType NoteProperty -Name 'Windows operating system up-to-date' -Value $updateAge


# Output for Intune
# return $cyberEssentials | ConvertTo-Json -Compress

$cyberEssentials