<#
.SYNOPSIS


.DESCRIPTION
Takes parameters passed through the script to create Defender Antivirus scan schedules for full, quick, and regular, and output the configuration
to either a mobileconfig for use in Microsoft Intune, or plist for use in Third-Party MDM solutions

.PARAMETER mdm
Configures whether profile file are created as mobileconfig for Intune, or plist for Third-Party MDM solutions.
Valid options are 'Intune' or 'ThirdParty'

.PARAMETER organisation
String, default is 'MEM v ENNBEE': Configures the organisation name in the mobileconfig file.

.PARAMETER fullScan
Boolean, required: if true allow for configuration of a Full Defender scan.

.PARAMETER fullScanDay
String range, default is 'Fri': the day of the week you want the full scan to run, or 'All' for every day.

.PARAMETER fullScanHour
Integer range between 0-23, default is '10': the hour you want the full scan to run.

.PARAMETER fullScanMinute
Integer range between 0-59, default is '30': the minute you want the full scan to run.

.PARAMETER dailyScan
Boolean, if true allow for configuration of a daily quick Defender scan.

.PARAMETER dailyScanHour
Integer range between 0-23, default is '12': the hour you want the daily quick scan to run.

.PARAMETER dailyScanMinute
Integer range between 0-59, default is '30': the minute you want the daily quick scan to run.

.PARAMETER regularScanInterval
Integer range between 0-24, default is '0': how frequently a regular quick scan is run in a day, '6' will run a scan every six hours, '24' will run a scan every day.

.PARAMETER randomizeScanStartTime
Integer range between 0-24, default is '0': allows the scan to run at a time between the scheduled scan time and the configured randomizeScanStartTime hour value.

.PARAMETER checkForDefinitionsUpdate
Boolean, default is true: will check for new definition updates before any scheduled scan.

.PARAMETER ignoreExclusions
Boolean, default is false: will adhere to exclusion settings for any scheduled scan.

.PARAMETER lowPriorityScheduledScan
Boolean, default is false: will run the scan at a low priority which may cause the scan to take longer than expected.

.PARAMETER runScanWhenIdle
Boolean, default is false: will run the scan within the scheduled time and not wait for the device to be idle.

.INPUTS
None. You can't pipe objects to New-macOSDefenderScanProfile.

.OUTPUTS
New-macOSDefenderScanProfile creates a mobileconfig and plist files in the same folder as the script.

.EXAMPLE
Create an Intune profile with full scan at 14:00 on a Wednesday, and daily scan at 10:30
PS> .\New-macOSDefenderScanProfile -mdm Intune -fullScan $true -fullScanDay Wed -fullScanHour 14 -fullScanMinute 00 -dailyScan $true -dailyScanHour 10 -dailyScanMinute 30

.EXAMPLE
Create a Third Party profile with full scan at 11:45 on a Monday, no daily scan configured, regular scan every 12 hours, and random start time of 1 hour.
PS> .\New-macOSDefenderScanProfile -mdm ThirdParty -fullScan $true -fullScanDay Mon -fullScanHour 11 -fullScanMinute 45 -regularScanInterval 12 -randomizeScanStartTime 1

#>

[CmdletBinding()]

param(

    [Parameter(Mandatory = $true)]
    [ValidateSet('Intune', 'ThirdParty')]
    [String]$mdm,

    [Parameter(Mandatory = $false)]
    [String]$organisation = 'MEM v ENNBEE',

    [Parameter(Mandatory = $true)]
    [boolean]$fullScan,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'All', 'Never')]
    [String]$fullScanDay = 'Fri',

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 23)]
    [int]$fullScanHour = '10',

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 59)]
    [int]$fullScanMinute = '30',

    [Parameter(Mandatory = $true)]
    [boolean]$dailyScan,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 23)]
    [int]$dailyScanHour = '12',

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 59)]
    [int]$dailyScanMinute = '30',

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 24)]
    [Int]$regularScanInterval = '0',

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 23)]
    [Int]$randomizeScanStartTime = '0',

    [Parameter(Mandatory = $false)]
    [boolean]$checkForDefinitionsUpdate = $true,

    [Parameter(Mandatory = $false)]
    [boolean]$ignoreExclusions = $false,

    [Parameter(Mandatory = $false)]
    [boolean]$lowPriorityScheduledScan = $false,

    [Parameter(Mandatory = $false)]
    [boolean]$runScanWhenIdle = $false

)

<#region testing
$mdm = 'ThirdParty'
$organisation = 'MEM v ENNBEE'
$fullScan = $true
$fullScanDay = 'Fri'
[int]$fullScanHour = '00'
[int]$fullScanMinute = '30'
$dailyScan = $true
[int]$dailyScanHour = '09'
[int]$dailyScanMinute = '30'
$regularScanInterval = '0'
$checkForDefinitionsUpdate = $true
$ignoreExclusions = $false
$lowPriorityScheduledScan = $false
$runScanWhenIdle = $false
$randomizeScanStartTime = '0'
#endregion testing#>

#region functions
function Format-XML ([xml]$xml, $indent = 2) {
    $StringWriter = New-Object System.IO.StringWriter
    $XmlWriter = New-Object System.XMl.XmlTextWriter $StringWriter
    $xmlWriter.Formatting = 'indented'
    $xmlWriter.Indentation = $Indent
    $xml.WriteContentTo($XmlWriter)
    $XmlWriter.Flush()
    $StringWriter.Flush()
    Write-Output $StringWriter.ToString()
    #https://devblogs.microsoft.com/powershell/format-xml/
}
#endregion functions

#region validation
if ($fullScan -eq $false -and $dailyScan -eq $false -and $regularScanInterval -eq '0') {
    Write-Host 'You have not configured any scan options.' -ForegroundColor Red
    Break
}
#endregion validation

#region variables
# setting boolean variables to string and lower case
$checkForDefinitionsUpdateString = $checkForDefinitionsUpdate.ToString().ToLower()
$ignoreExclusionsString = $ignoreExclusions.ToString().ToLower()
$lowPriorityScheduledScanString = $lowPriorityScheduledScan.ToString().ToLower()
$runScanWhenIdleString = $runScanWhenIdle.ToString().ToLower()

# creating UUIDs for Intune payload
$configpayloadUUID = New-Guid
$configpayloadUUID = $(($configpayloadUUID.Guid).ToUpper())
$contentPayloadUUID = New-Guid
$contentPayloadUUID = $(($contentPayloadUUID.Guid).ToUpper())

$configHead = @'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">

'@

$configHeader = @'
<plist version="1.0">
    <dict>

'@

# start of the file for Intune
$configStartIntune = @"
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

"@

# start of the configuration for all MDMs
$configSettingsStart = @"
<key>features</key>
<dict>
    <key>scheduledScan</key>
    <string>enabled</string>
</dict>
<key>scheduledScan</key>
<dict>
    <key>ignoreExclusions</key>
    <$ignoreExclusionsString/>
    <key>lowPriorityScheduledScan</key>
    <$lowPriorityScheduledScanString/>
    <key>randomizeScanStartTime</key>
    <integer>$randomizeScanStartTime</integer>
    <key>checkForDefinitionsUpdate</key>
    <$checkForDefinitionsUpdateString/>
    <key>runScanWhenIdle</key>
    <$runScanWhenIdleString/>

"@

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
            'Never' { '8' }
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
else {
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
if ($dailyScan -eq $true) {
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
    <string>$regularScanInterval</string>
</dict>

"@
    }
}
else {

    $configSettingsQuick = @"
<key>dailyConfiguration</key>
<dict>
    <key>interval</key>
    <string>$regularScanInterval</string>
</dict>

"@
}

$configSettingsEndIntune = @'
        </dict>
    </dict>
</array>

'@

$configSettingsEndThirdParty = @'
</dict>

'@

$configFooter = @'
    </dict>
</plist>
'@
#endregion variables

#region config export
Try {
    $date = Get-Date -Format yyyyMMddHHmm
    if ($mdm -eq 'Intune') {
        $configFile = "com.microsoft.wdav.$date.mobileconfig"
        $configSettings = $configSettingsStart + $configSettingsQuick + $configSettingsFull + $configSettingsEndIntune
        $configXML = $configHeader + $configStartIntune + $configSettings + $configFooter
    }
    else {
        $configFile = "com.microsoft.wdav.$date.plist"
        $configSettings = $configSettingsStart + $configSettingsQuick + $configSettingsFull + $configSettingsEndThirdParty
        $configXML = $configHeader + $configSettings + $configFooter
    }

    #$configContent = $configHead + $configXML
    $configContent = $configHead + $(Format-XML $configXML)
    $configContent | Out-File -FilePath $configFile
    Write-Host "Configuration profile for $mdm written to $configFile" -ForegroundColor Green
}
Catch {
    Write-Host "Unable to write file $configfile to current location."
    Break
}
#endregion config export