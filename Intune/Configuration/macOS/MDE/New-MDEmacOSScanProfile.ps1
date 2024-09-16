<#
.SYNOPSIS

.DESCRIPTION


.PARAMETER tenantId
Provide the Id of the tenant to connecto to.

.INPUTS
None. You can't pipe objects to New-MDEmacOSScanProfile.ps1.

.OUTPUTS
New-MDEmacOSScanProfile.ps1 creates a mobileconfig file in the same folder as the script.

.EXAMPLE
Creates a new macOS MDE profile to configure no full scan, but daily scan at 10:30
PS> .\New-MDEmacOSScanProfile.ps1 -organisation 'MEM v ENNBEE' -fullScanDay None -dailyScanHour 10 -dailyScanMinute 30

.EXAMPLE
Creates a new macOS MDE profile to configure a full scan on a Wednesday at 14:45, but daily scan at 10:30
PS> .\New-MDEmacOSScanProfile.ps1 -organisation 'MEM v ENNBEE' -fullScanDay Wed -dailyScanHour 10 -dailyScanMinute 30

#>

[CmdletBinding()]

param(

    [Parameter(Mandatory = $false)]
    [String]$organisation = 'MEM v ENNBEE',

    [Parameter(Mandatory = $true)]
    [boolean]$fullScan,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'All')]
    [String]$fullScanDay = 'Fri',

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 23)]
    [int]$fullScanHour = '10',

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 60)]
    [int]$fullScanMinute = '30',

    [Parameter(Mandatory = $true)]
    [boolean]$dailyScan,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 23)]
    [int]$dailyScanHour = '12',

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 60)]
    [int]$dailyScanMinute = '30',

    [Parameter(Mandatory = $true)]
    [boolean]$regularScan,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 24)]
    [Int]$regularScanInterval,

    [Parameter(Mandatory = $false)]
    [ValidateSet('true', 'false')]
    [String]$ignoreExclusions = 'false',

    [Parameter(Mandatory = $false)]
    [ValidateSet('true', 'false')]
    [String]$lowPriorityScheduledScan = 'true'

)

#region testing
$fullScan = $true
$fullScanDay = 'Fri'
[int]$fullScanHour = '15'
[int]$fullScanMinute = '00'
$dailyScan = $true
[int]$dailyScanHour = '12'
[int]$dailyScanMinute = '15'
$regularScan = $false
$regularScanInterval = '6'
$ignoreExclusions = 'false'
$lowPriorityScheduledScan = 'true'
#endregion testing

#region validation
$configpayloadUUID = New-Guid
$configpayloadUUID = $(($configpayloadUUID.Guid).ToUpper())
$contentPayloadUUID = New-Guid
$contentPayloadUUID = $(($contentPayloadUUID.Guid).ToUpper())

$configStart = @"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
    <dict>
        <key>PayloadUUID</key>
        <string>$configpayloadUUID</string>
        <key>PayloadType</key>
        <string>Configuration</string>
        <key>PayloadOrganization</key>
        <string>$organisation</string>
        <key>PayloadIdentifier</key>
        <string>$configpayloadUUID</string>
        <key>PayloadDisplayName</key>
        <string>Microsoft Defender for Endpoint settings</string>
        <key>PayloadDescription</key>
        <string>Microsoft Defender for Endpoint configuration settings</string>
        <key>PayloadVersion</key>
        <integer>1</integer>
        <key>PayloadEnabled</key>
        <true/>
        <key>PayloadRemovalDisallowed</key>
        <false/>
        <key>PayloadScope</key>
        <string>System</string>
        <key>PayloadContent</key>

"@

$configSettingsStart = @"
        <array>
            <dict>
                <key>PayloadUUID</key>
                <string>$contentPayloadUUID</string>
                <key>PayloadType</key>
                <string>com.microsoft.wdav</string>
                <key>PayloadOrganization</key>
                <string>$organisation</string>
                <key>PayloadIdentifier</key>
                <string>$contentPayloadUUID</string>
                <key>PayloadDisplayName</key>
                <string>Microsoft Defender for Endpoint configuration settings</string>
                <key>PayloadDescription</key>
                <string/>
                <key>PayloadVersion</key>
                <integer>1</integer>
                <key>PayloadEnabled</key>
                <true/>
                <key>features</key>
                <dict>
                    <key>scheduledScan</key>
                    <string>enabled</string>
                </dict>
                <key>scheduledScan</key>
                <dict>
                    <key>ignoreExclusions</key>
                    <$ignoreExclusions/>
                    <key>lowPriorityScheduledScan</key>
                    <$lowPriorityScheduledScan/>

"@

if ($fullScan -eq $false) {
    $fullScanDay = 'Never'
    $configSettingsFull = @'
                    <key>weeklyConfiguration</key>
                    <dict>
                        <key>dayOfWeek</key>
                        <integer>8</integer>
                        <key>scanType</key>
                        <string>full</string>
                    </dict>

'@
}
if ($fullScan -eq $true) {
    if ([string]::IsNullOrEmpty($fullScanDay) -or [string]::IsNullOrEmpty($fullScanHour) -or [string]::IsNullOrEmpty($fullScanMinute)) {
        Write-Host 'Defender Full Scan configured but missing scan day or hour or minute.' -ForegroundColor Red
        Break
    }
    else {
        $dayOfWeek = switch ($fullScanDay) {
            'All' { '0' }
            'Sun' { '1' }
            'Mon' { '2' }
            'Tue' { '3' }
            'Wed' { '4' }
            'Thu' { '5' }
            'Fri' { '6' }
            'Sat' { '7' }
        }
        [int]$fullScanTimeOfDay = $fullScanHour * 60 + $fullScanMinute

        $configSettingsFull = @"
                    <key>weeklyConfiguration</key>
                    <dict>
                        <key>dayOfWeek</key>
                        <integer>$dayOfWeek</integer>
                        <key>timeOfDay</key>
                        <integer>$fullScanTimeOfDay</integer>
                        <key>scanType</key>
                        <string>full</string>
                    </dict>

"@
    }
}
if ($dailyScan -eq $true -and $regularScan -eq $false) {
    $regularScanInterval = 'Never'
    if ([string]::IsNullOrEmpty($dailyScanHour) -or [string]::IsNullOrEmpty($dailyScanMinute)) {
        Write-Host 'Defender Daily Scan configured but missing scan hour or minute.' -ForegroundColor Red
        Break
    }
    else {
        [int]$dailyScanTimeOfDay = $dailyScanHour * 60 + $dailyScanMinute

        $configSettingsQuick = @"
                    <key>dailyConfiguration</key>
                    <dict>
                        <key>timeOfDay</key>
                        <integer>$dailyScanTimeOfDay</integer>
                        <key>interval</key>
                        <string>0</string>
                    </dict>

"@
    }
}
elseif ($dailyScan -eq $true -and $regularScan -eq $true) {
    if ([string]::IsNullOrEmpty($dailyScanHour) -or [string]::IsNullOrEmpty($dailyScanMinute)) {
        Write-Host 'Defender Daily Scan configured but missing scan hour or minute.' -ForegroundColor Red
        Break
    }
    if ([string]::IsNullOrEmpty($regularScanInterval)) {
        Write-Host 'Defender Regular Scan configured but missing scan interval.' -ForegroundColor Red
        Break
    }
    $configSettingsQuick = @"
        <key>dailyConfiguration</key>
        <dict>
            <key>timeOfDay</key>
            <integer>$quickScanTimeOfDay</integer>
            <key>interval</key>
            <string>$regularScanInterval</string>
        </dict>

"@
}
elseif ($dailyScan -eq $false -and $regularScan -eq $true) {
    $dailyScanTimeOfDay = 'Never'
    if ([string]::IsNullOrEmpty($regularScanInterval)) {
        Write-Host 'Defender Regular Scan configured but missing scan interval.' -ForegroundColor Red
        Break
    }
    $configSettingsQuick = @"
        <key>dailyConfiguration</key>
        <dict>
            <key>interval</key>
            <string>$regularScanInterval</string>
        </dict>

"@
}

$configSettingsEnd = @'
                </dict>
            </dict>
        </array>

'@

$configEnd = @'
    </dict>
</plist>
'@
#endregion validation


Try {
    $configSettings = $configSettingsStart + $configSettingsQuick + $configSettingsFull + $configSettingsEnd
    $configContent = $configStart + $configSettings + $configEnd
    $configfile = "MDEConfig_FullScan$fullScanDay$fullScanTimeOfDay`_DailyScan$dailyScanTimeOfDay`_RegularScan$regularScanInterval.mobileconfig"
    $configContent | Out-File -FilePath $configfile
}
Catch {
    Write-Host "Unable to write file $configfile to current location."
    Break
}
