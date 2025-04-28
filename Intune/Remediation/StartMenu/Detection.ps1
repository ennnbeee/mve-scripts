New-PSDrive HKU Registry HKEY_USERS | Out-Null
$userName = Get-WmiObject -Class Win32_Computersystem | Select-Object Username;
$userSID = (New-Object System.Security.Principal.NTAccount($userName.UserName)).Translate([System.Security.Principal.SecurityIdentifier]).value
$regSetting = 'TaskbarAl'
$regSettingValue = 0 # 0 is left, 1 is centre
$regKey = "HKU:\$userSID\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$regValues = (Get-Item $regKey).Property

if ($regValues -notcontains $regSetting) {
    $remediationNeeded = $true
}
else {
    $regValue = Get-ItemPropertyValue -Path $regKey -Name $regSetting
    if ($regValue -ne $regSettingValue) {
        $remediationNeeded = $true
    } else {
        $remediationNeeded = $false
    }
}

Remove-PSDrive -Name HKU -Force | Out-Null

if ($remediationNeeded -eq $true) {
    Write-Output 'Windows Start Menu registry settings are incorrect'
    exit 1
}
else {
    Write-Output 'Windows Start Menu registry settings are correct'
    exit 0
}