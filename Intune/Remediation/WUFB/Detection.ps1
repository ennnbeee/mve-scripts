$transcriptPath = "$env:ProgramData\Microsoft\IntuneManagementExtension\Logs"
$transcriptName = 'WUFB-Detection.log'
New-Item $transcriptPath -ItemType Directory -Force

# Stopping orphaned transcripts
try {
    Stop-Transcript | Out-Null
}
catch [System.InvalidOperationException]
{}

Start-Transcript -Path $transcriptPath\$transcriptName -Append

# WUFB settings
[PsObject[]]$regKeysWUFB = @()
# Keys for Windows Update for Business
$regKeysWUFB += [PsObject]@{ Name = 'DoNotConnectToWindowsUpdateInternetLocations'; path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\' }
$regKeysWUFB += [PsObject]@{ Name = 'DisableWindowsUpdateAccess'; path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\' }
$regKeysWUFB += [PsObject]@{ Name = 'NoAutoUpdate'; path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\' }
# Comment out these Keys if Co-managed
#$regKeysWUFB += [PsObject]@{ Name = 'WUServer'; path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\' }
#$regKeysWUFB += [PsObject]@{ Name = 'DisableDualScan'; path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\' }
#$regKeysWUFB += [PsObject]@{ Name = 'UseWUServer'; path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU\' }
# Registry keys for Feature Update target versions
$regKeysWUFB += [PsObject]@{ Name = 'ProductVersion'; path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\' }
$regKeysWUFB += [PsObject]@{ Name = 'TargetReleaseVersion'; path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\' }
$regKeysWUFB += [PsObject]@{ Name = 'TargetReleaseVersionInfo'; path = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\' }

foreach ($setting in $regKeysWUFB) {
    Write-Host "Checking $($setting.name)"
    if ((Get-Item $setting.path -ErrorAction Ignore).Property -contains $setting.name) {
        Write-Host "$($setting.name) is not correct"
        $remediationNeeded = $true
    }
}

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
    Write-Host 'Windows Update registry settings are incorrect'
    exit 1
}
else {
    Stop-Transcript
    Write-Host 'Windows Update registry settings are correct'
    exit 0
}