<#
.SYNOPSIS

.DESCRIPTION


.PARAMETER mdm
Provide the Id of the tenant to connecto to.

.INPUTS
None. You can't pipe objects to New-MDEmacOSScanProfile.ps1.

.OUTPUTS
New-MDEmacOSScanProfile.ps1 creates a mobileconfig file in the same folder as the script.

.EXAMPLE
Creates a new macOS MDE profile to configure no full scan, but daily scan at 10:30
PS> .\New-MDEmacOSScanProfile.ps1 -organisation 'MEM v ENNBEE'

.EXAMPLE
Creates a new macOS MDE profile to configure a full scan on a Wednesday at 14:45, but daily scan at 10:30
PS> .\New-MDEmacOSScanProfile.ps1 -organisation 'MEM v ENNBEE'

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
    [boolean]$checkForDefinitionsUpdate = $true,

    [Parameter(Mandatory = $false)]
    [boolean]$ignoreExclusions = $false,

    [Parameter(Mandatory = $false)]
    [boolean]$lowPriorityScheduledScan = $true,

    [Parameter(Mandatory = $false)]
    [boolean]$runScanWhenIdle = $false,

    [Parameter(Mandatory = $false)]
    [ValidateRange(0, 23)]
    [Int]$randomizeScanStartTime = '0'

)

<#region testing
$mdm = 'Intune'
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
$lowPriorityScheduledScan = $true
$runScanWhenIdle = $false
$randomizeScanStartTime = '0'
#endregion testing#>

#region functions
function Format-XML ([xml]$xml, $indent=2)
{
    $StringWriter = New-Object System.IO.StringWriter
    $XmlWriter = New-Object System.XMl.XmlTextWriter $StringWriter
    $xmlWriter.Formatting = “indented”
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
$checkForDefinitionsUpdate = $(([string]$checkForDefinitionsUpdate).ToLower())
$ignoreExclusions = $(([string]$ignoreExclusions).ToLower())
$lowPriorityScheduledScan = $(([string]$lowPriorityScheduledScan).ToLower())
$runScanWhenIdle = $(([string]$runScanWhenIdle).ToLower())

# creating UUIDs for Intune payload
$configpayloadUUID = New-Guid
$configpayloadUUID = $(($configpayloadUUID.Guid).ToUpper())
$contentPayloadUUID = New-Guid
$contentPayloadUUID = $(($contentPayloadUUID.Guid).ToUpper())

$configHead = @'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">

'@

$configHeader = @"
<plist version="1.0">
    <dict>

"@

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
    <$ignoreExclusions/>
    <key>lowPriorityScheduledScan</key>
    <$lowPriorityScheduledScan/>
    <key>randomizeScanStartTime</key>
    <integer>$randomizeScanStartTime</integer>
    <key>checkForDefinitionsUpdate</key>
    <$checkForDefinitionsUpdate/>
    <key>runScanWhenIdle</key>
    <$runScanWhenIdle/>

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
        $configSettings = $configSettingsStart + $configSettingsFull + $configSettingsQuick + $configSettingsEndIntune
        $configXML = $configHeader + $configStartIntune + $configSettings + $configFooter
    }
    else {
        $configFile = "com.microsoft.wdav.$date.plist"
        $configSettings = $configSettingsStart + $configSettingsFull + $configSettingsQuick + $configSettingsEndThirdParty
        $configXML = $configHeader + $configSettings + $configFooter
    }

    #$configContent = $configHead + $configXML
    $configContent = $configHead + $(Format-XML $configXML)

    $configContent | Out-File -FilePath $configFile
}
Catch {
    Write-Host "Unable to write file $configfile to current location."
    Break
}
#endregion config export



