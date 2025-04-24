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
$regKeysStartMenu += [PsObject]@{ Name = 'TaskbarAl'; path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\'; value = 0; type = 'DWord' } # 0 is left, 1 is right


foreach ($setting in $regKeysStartMenu) {
    Write-Host "Checking $($setting.name)"
    if ((Get-Item $setting.path -ErrorAction Ignore).Property -contains $setting.name) {
        if ((Get-ItemPropertyValue -path $setting.Path -name $setting.Name) -ne $setting.value) {
            Write-Host "$($setting.name) value is not correct"
            $remediationNeeded = $true
        }
    }
    else {
        Write-Host "$($setting.name) value does not exist"
        $remediationNeeded = $true
    }
}

# check if remediation is needed
if ($remediationNeeded -eq $true) {
    Stop-Transcript
    Write-Host 'Windows Start Menu registry settings are incorrect'
    exit 1
}
else {
    Stop-Transcript
    Write-Host 'Windows Start Menu registry settings are correct'
    exit 0
}