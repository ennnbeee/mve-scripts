New-PSDrive HKU Registry HKEY_USERS | Out-Null
$userName = Get-WmiObject -Class Win32_Computersystem | Select-Object Username;
$userSID = (New-Object System.Security.Principal.NTAccount($userName.UserName)).Translate([System.Security.Principal.SecurityIdentifier]).value
$regSetting = 'TaskbarAl'
$regSettingValue = 0 # 0 is left, 1 is centre
$regKey = "HKU:\$userSID\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$regValues = (Get-Item $regKey).Property

if ($regValues -notcontains $regSetting) {
    Write-Output "Created registry setting $regSetting"
    New-ItemProperty -Path $regKey -Name $regSetting -Value $regSettingValue -PropertyType DWord -Force
}
else {
    Write-Output "Updated registry setting $regSetting"
    Set-ItemProperty -Path $regKey -Name $regSetting -Value $regSettingValue -Force
}
Remove-PSDrive -Name HKU -Force | Out-Null