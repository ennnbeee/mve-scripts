#region Variables
#Computer Name Settings
$namePrefix = 'ENB-'
#OOBE Settings
$regSettings = @()
$regSettings += [pscustomobject]@{path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE';name = 'PrivacyConsentStatus'; value = '0'; type = 'DWord'}
$regSettings += [pscustomobject]@{path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE';name = 'SkipMachineOOBE'; value = '1'; type = 'DWord'}
$regSettings += [pscustomobject]@{path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE';name = 'ProtectYourPC'; value = '3'; type = 'DWord'}
$regSettings += [pscustomobject]@{path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE';name = 'SkipUserOOBE'; value = '1'; type = 'DWord'}
$regSettings += [pscustomobject]@{path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE';name = 'LaunchUserOOBE'; value = '0'; type = 'DWord'}
$regSettings += [pscustomobject]@{path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE';name = 'DisablePrivacyExperience'; value = '1'; type = 'DWord'}
$regSettings += [pscustomobject]@{path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE';name = 'DisableVoice'; value = '1'; type = 'DWord'}
$regSettings += [pscustomobject]@{path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\OOBE';name = 'HideEULAPage'; value = '1'; type = 'DWord'}
$regSettings += [pscustomobject]@{path = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System';name = 'EnableFirstLogonAnimation'; value = '0'; type = 'DWord'}
#endregion Variables

Try {
    #OOBE
    foreach ($regSetting in $regSettings) {
        New-ItemProperty -Path $($regSetting.path) -Name $($regSetting.name) -Value $($regSetting.value) -PropertyType $($regSetting.type) -Force
    }
    #Rename
    $serialNumber = Get-WmiObject Win32_bios | Select-Object -ExpandProperty SerialNumber
    $computerName = (($namePrefix + $serialNumber).Replace(' ', ''))
    if ($computerName.Length -ge 15) {
        $computerName = $computerName.substring(0, 15)
    }

    Rename-Computer -NewName $newName
    & shutdown.exe /r /t 0 /f
}
Catch {
    Write-Error $_.ErrorDetails
    Exit 1
}

#Computer Name
$serial = Get-WmiObject Win32_bios | Select-Object -ExpandProperty SerialNumber
    If (Get-WmiObject -Class win32_battery) {
        $newName = 'L-' + $serial
    }
    Else {
        $newName = 'D-' + $serial
    }

    $newName = $newName.Replace(' ', '')
    if ($newName.Length -ge 15) {
        $newName = $newName.substring(0, 15)
    }

    Rename-Computer -NewName $newName