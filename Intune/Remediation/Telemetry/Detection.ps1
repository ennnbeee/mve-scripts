$transcriptPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"
$transcriptName = 'Telemetry-Detection.log'
New-Item $transcriptPath -ItemType Directory -Force

# Stopping orphaned transcripts
try {
    Stop-Transcript | Out-Null
}
catch [System.InvalidOperationException]
{}

Start-Transcript -Path $transcriptPath\$transcriptName -Append

# Telemetry settings
[PsObject[]]$regKeysTelemetry = @()
# Telemetry keys and values
$regKeysTelemetry += [PsObject]@{ Name = 'AllowTelemetry'; path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection\'; value = 3; type = 'DWord' }
$regKeysTelemetry += [PsObject]@{ Name = 'AllowTelemetry_PolicyManager'; path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection\'; value = 3; type = 'DWord' }
$regKeysTelemetry += [PsObject]@{ Name = 'LimitDumpCollection'; path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection\'; value = 1; type = 'DWord' }
$regKeysTelemetry += [PsObject]@{ Name = 'LimitDiagnosticLogCollection'; path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection\'; value = 1; type = 'DWord' }
$regKeysTelemetry += [PsObject]@{ Name = 'DisableTelemetryOptInSettingsUx'; path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection\'; value = 1; type = 'DWord' }
$regKeysTelemetry += [PsObject]@{ Name = 'DisableTelemetryOptInChangeNotification'; path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection\'; value = 1; type = 'DWord' }
$regKeysTelemetry += [PsObject]@{ Name = 'AllowDeviceNameInTelemetry'; path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection\'; value = 1; type = 'DWord' }

foreach ($setting in $regKeysTelemetry) {
    Write-Host "Checking $($setting.name)"
    if ((Get-Item $setting.path -ErrorAction Ignore).Property -contains $setting.name) {
        if ((Get-ItemPropertyValue -path $setting.Path -name $setting.Name) -ne $setting.value) {
            Write-Host "$($setting.name) value is not correct"
            $remediationNeeded = $true
        }
    }
    else {
        Write-Host "$($setting.name) does not exist"
        $remediationNeeded = $true
    }
}

# check if remediation is needed
if ($remediationNeeded -eq $true) {
    Stop-Transcript
    Write-Host 'Windows Telemetry registry settings are incorrect'
    exit 1
}
else {
    Stop-Transcript
    Write-Host 'Windows Telemetry registry settings are correct'
    exit 0
}