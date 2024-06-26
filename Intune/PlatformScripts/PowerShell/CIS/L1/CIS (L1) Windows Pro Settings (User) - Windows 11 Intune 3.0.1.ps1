# Windows Pro User Settings
$regSettings = @()
$regSettings += [pscustomobject]@{path = 'HKCU:\Software\Policies\Microsoft\Windows\CloudContent'; name = 'DisableSpotlightCollectionOnDesktop'; value = '1'; type = 'DWord' }

Try {
    foreach ($regSetting in $regSettings) {
        if (!(Test-Path $($regSetting.path))){
            New-Item -Path $($regSetting.path) -Force
        }
        New-ItemProperty -Path $($regSetting.path) -Name $($regSetting.name) -Value $($regSetting.value) -PropertyType $($regSetting.type) -Force
    }
    Exit 0
}
Catch {
    Write-Error $_.ErrorDetails
    Exit 1
}
