# Start Menu settings
[PsObject[]]$regKeysStartMenu = @()
# Start Menu keys and values
$regKeysStartMenu += [PsObject]@{ Name = 'TaskbarAl'; path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\'; value = 0; type = 'DWord' } # 0 is left, 1 is right

foreach ($setting in $regKeysStartMenu) {
    if ((Get-Item $setting.path -ErrorAction Ignore).Property -contains $setting.name) {
        if ((Get-ItemPropertyValue -path $setting.Path -name $setting.Name) -ne $setting.value) {
            Set-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.value
        }
    }
    else {
        New-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.value -PropertyType $setting.type -Force
    }
}