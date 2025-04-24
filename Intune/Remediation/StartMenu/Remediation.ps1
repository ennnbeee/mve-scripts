$transcriptPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"
$transcriptName = 'StartMenu-Detection.log'
New-Item $transcriptPath -ItemType Directory -Force

# Stopping orphaned transcripts
try {
    Stop-Transcript | Out-Null
}
catch [System.InvalidOperationException]
{}

Start-Transcript -Path $transcriptPath\$transcriptName -Append

# Start Menu settings
[PsObject[]]$regKeysStartMenu = @()
# Start Menu keys and values
$regKeysStartMenu += [PsObject]@{ Name = 'TaskbarAl'; path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\'; value = 0; type = 'DWord' }

foreach ($setting in $regKeysStartMenu) {
    Write-Host "Checking $($setting.name)"
    if ((Get-Item $setting.path -ErrorAction Ignore).Property -contains $setting.name) {
        if ((Get-ItemPropertyValue -Path $setting.Path -Name $setting.Name) -ne $setting.value) {
            Write-Host "Remediating $($setting.name)"
            Set-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.value
        }
    }
    else {
        Write-Host "Remediating $($setting.name)"
        New-ItemProperty -Path $setting.Path -Name $setting.Name -Value $setting.value -PropertyType $setting.type -Force | Out-Null
    }
}

Stop-Transcript
Write-Host 'Windows Start Menu registry settings are correct'
Exit 0