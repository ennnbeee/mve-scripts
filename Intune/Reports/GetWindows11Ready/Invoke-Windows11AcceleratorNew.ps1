<#
.SYNOPSIS
Allows for a phased and controlled distribution of Windows 11 Feature Updates
following the run and capture of Update Readiness data, tagging devices
in Entra ID with their update readiness risk score for use with Dynamic
Security Groups.

.DESCRIPTION
The Invoke-Windows11Accelerator script allows for the controlled roll out of
Windows 11 Feature Updates based on device readiness risk assements data.

.PARAMETER tenantId
Provide the Id of the tenant to connecto to.

.PARAMETER featureUpdateBuild
Select the Windows 11 Feature Update verion you wish to deploy
Choice of 22H2 or 23H2.

.PARAMETER extensionAttribute
Configure the device extensionAttribute to be used for tagging Entra ID objects
with their Feature Update Readiness Assessment risk score.
Choice of 1 to 15

.PARAMETER target
Select the whether you want to target the deployment to groups of users or groups of devices.
Choice of Users or Devices.

.PARAMETER Scopes
The scopes used to connect to the Graph API using PowerShell.
Default scopes configured are:
'Group.ReadWrite.All,Device.ReadWrite.All,DeviceManagementManagedDevices.ReadWrite.All,DeviceManagementConfiguration.ReadWrite.All'

.INPUTS
None. You can't pipe objects to Invoke-Windows11Accelerator.

.OUTPUTS
None. Invoke-Windows11Accelerator doesn't generate any output.

.EXAMPLE
PS> .\Invoke-Windows11Accelerator.ps1 -tenantId 36019fe7-a342-4d98-9126-1b6f94904ac7 -featureUpdateBuild 23H2 -target Devices -extensionAttribute 15

.EXAMPLE
PS> .\Invoke-Windows11Accelerator.ps1 -tenantId 36019fe7-a342-4d98-9126-1b6f94904ac7 -featureUpdateBuild 22H2 -target Users -extensionAttribute 10

#>

[CmdletBinding()]

param(

    [Parameter(Mandatory = $true)]
    [String]$tenantId,

    [Parameter(Mandatory = $true)]
    [ValidateSet('22H2', '23H2')]
    [String]$featureUpdateBuild = '23H2',

    [Parameter(Mandatory = $true)]
    [ValidateSet('user', 'device')]
    [String]$target = 'user',

    [Parameter(Mandatory = $true)]
    [ValidateRange(1, 15)]
    [String]$extensionAttribute,

    [Parameter(Mandatory = $false)]
    [String[]]$scopes = 'Group.ReadWrite.All,Device.ReadWrite.All,DeviceManagementManagedDevices.ReadWrite.All,DeviceManagementConfiguration.ReadWrite.All,User.ReadWrite.All'

)

$tenantId = '437e8ffb-3030-469a-99da-e5b527908010'

$extensionAttribute = '10'
#region Functions
Function Test-JSON() {

    param (
        $JSON
    )

    try {
        $TestJSON = ConvertFrom-Json $JSON -ErrorAction Stop
        $TestJSON | Out-Null
        $validJson = $true
    }
    catch {
        $validJson = $false
        $_.Exception
    }
    if (!$validJson) {
        Write-Host "Provided JSON isn't in valid JSON format" -f Red
        break
    }

}
Function New-ReportFeatureUpdateReadiness() {

    [cmdletbinding()]

    param
    (
        [parameter(Mandatory = $true)]
        $JSON
    )

    $graphApiVersion = 'Beta'
    $Resource = 'deviceManagement/reports/cachedReportConfigurations'

    try {
        Test-Json -Json $JSON
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        Invoke-MgGraphRequest -Uri $uri -Method Post -Body $JSON -ContentType 'application/json'
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Get-ReportFeatureUpdateReadiness() {

    [cmdletbinding()]

    param (

        [parameter(Mandatory = $false)]
        $Id,

        [parameter(Mandatory = $false)]
        $JSON

    )

    $graphApiVersion = 'Beta'

    if ($id) {
        $Resource = "deviceManagement/reports/cachedReportConfigurations('$Id')"
    }
    elseif ($JSON) {
        $Resource = 'deviceManagement/reports/getCachedReport'
    }

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        if ($id) {
            Invoke-MgGraphRequest -Uri $uri -Method Get
        }
        elseif ($JSON) {
            $tempFile = [System.IO.Path]::GetTempFileName()
            Invoke-MgGraphRequest -Uri $uri -Method Post -Body $JSON -ContentType 'application/json' -OutputFilePath $tempFile
            Get-Content -Raw $tempFile | ConvertFrom-Json
            Remove-Item $tempFile
        }

    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Add-ObjectAttribute() {

    [cmdletbinding()]

    param
    (

        [parameter(Mandatory = $true)]
        [ValidateSet('User', 'Device')]
        $object,

        [parameter(Mandatory = $true)]
        $JSON,

        [parameter(Mandatory = $true)]
        $Id
    )

    $graphApiVersion = 'Beta'
    if ($object -eq 'User') {
        $Resource = "users/$Id"
    }
    else {
        $Resource = "devices/$Id"
    }

    try {
        Test-Json -Json $JSON
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        Invoke-MgGraphRequest -Uri $uri -Method Patch -Body $JSON -ContentType 'application/json'
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Get-EntraIDObject() {

    [cmdletbinding()]
    param
    (

        [parameter(Mandatory = $true)]
        [ValidateSet('User', 'Device')]
        $object

    )

    $graphApiVersion = 'beta'
    if ($object -eq 'User') {
        $Resource = 'users'
    }
    else {
        $Resource = 'devices'
    }

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $GraphResults = Invoke-MgGraphRequest -Uri $uri -Method Get

        $Results = @()
        $Results += $GraphResults.value

        $Pages = $GraphResults.'@odata.nextLink'
        while ($null -ne $Pages) {

            $Additional = Invoke-MgGraphRequest -Uri $Pages -Method Get

            if ($Pages) {
                $Pages = $Additional.'@odata.nextLink'
            }
            $Results += $Additional.value
        }
        $Results
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}

#endregion Functions

#region authentication
if (Get-MgContext) {
    Write-Host 'Disconnecting from existing Graph session.' -ForegroundColor Cyan
    Disconnect-MgGraph
}
$moduleName = 'Microsoft.Graph'
$Module = Get-InstalledModule -Name $moduleName
if ($Module.count -eq 0) {
    Write-Host "$moduleName module is not available" -ForegroundColor yellow
    $Confirm = Read-Host Are you sure you want to install module? [Y] Yes [N] No
    if ($Confirm -match '[yY]') {
        Install-Module -Name $moduleName -AllowClobber -Scope AllUsers -Force
    }
    else {
        Write-Host "$moduleName module is required. Please install module using 'Install-Module $moduleName -Scope AllUsers -Force' cmdlet." -ForegroundColor Yellow
        break
    }
}
else {
    If ($IsMacOS) {
        Connect-MgGraph -Scopes $scopes -UseDeviceAuthentication -TenantId $tenantId
        Write-Host 'Disconnecting from Graph to allow for changes to consent requirements' -ForegroundColor Cyan
        Disconnect-MgGraph
        Write-Host 'Connecting to Graph' -ForegroundColor Cyan
        Connect-MgGraph -Scopes $scopes -UseDeviceAuthentication -TenantId $tenantId

    }
    ElseIf ($IsWindows) {
        Connect-MgGraph -Scopes $scopes -UseDeviceCode -TenantId $tenantId
        Write-Host 'Disconnecting from Graph to allow for changes to consent requirements' -ForegroundColor Cyan
        Disconnect-MgGraph
        Write-Host 'Connecting to Graph' -ForegroundColor Cyan
        Connect-MgGraph -Scopes $scopes -UseDeviceAuthentication -TenantId $tenantId
    }
    Else {
        Connect-MgGraph -Scopes $scopes -TenantId $tenantId
        Write-Host 'Disconnecting from Graph to allow for changes to consent requirements' -ForegroundColor Cyan
        Disconnect-MgGraph
        Write-Host 'Connecting to Graph' -ForegroundColor Cyan
        Connect-MgGraph -Scopes $scopes -TenantId $tenantId
    }

    $graphDetails = Get-MgContext
    if ($null -eq $graphDetails) {
        Write-Host "Not connected to Graph, please review any errors and try to run the script again' cmdlet." -ForegroundColor Red
        break
    }
}
#endregion authentication

#region Variables
$ProgressPreference = 'SilentlyContinue';
$rndWait = Get-Random -Minimum 1 -Maximum 5
$extensionAttribute = 'extensionAttribute' + $extensionAttribute
#endregion Variables


Write-Host '░██╗░░░░░░░██╗██╗███╗░░██╗██████╗░░█████╗░░██╗░░░░░░░██╗░██████╗  ░░███╗░░░░███╗░░'
Write-Host '░██║░░██╗░░██║██║████╗░██║██╔══██╗██╔══██╗░██║░░██╗░░██║██╔════╝  ░████║░░░████║░░'
Write-Host '░╚██╗████╗██╔╝██║██╔██╗██║██║░░██║██║░░██║░╚██╗████╗██╔╝╚█████╗░  ██╔██║░░██╔██║░░'
Write-Host '░░████╔═████║░██║██║╚████║██║░░██║██║░░██║░░████╔═████║░░╚═══██╗  ╚═╝██║░░╚═╝██║░░'
Write-Host '░░╚██╔╝░╚██╔╝░██║██║░╚███║██████╔╝╚█████╔╝░░╚██╔╝░╚██╔╝░██████╔╝  ███████╗███████╗'
Write-Host '░░░╚═╝░░░╚═╝░░╚═╝╚═╝░░╚══╝╚═════╝░░╚════╝░░░░╚═╝░░░╚═╝░░╚═════╝░  ╚══════╝╚══════╝'
Write-Host ''
Write-Host '░█████╗░░█████╗░░█████╗░███████╗██╗░░░░░███████╗██████╗░░█████╗░████████╗░█████╗░██████╗░'
Write-Host '██╔══██╗██╔══██╗██╔══██╗██╔════╝██║░░░░░██╔════╝██╔══██╗██╔══██╗╚══██╔══╝██╔══██╗██╔══██╗'
Write-Host '███████║██║░░╚═╝██║░░╚═╝█████╗░░██║░░░░░█████╗░░██████╔╝███████║░░░██║░░░██║░░██║██████╔╝'
Write-Host '██╔══██║██║░░██╗██║░░██╗██╔══╝░░██║░░░░░██╔══╝░░██╔══██╗██╔══██║░░░██║░░░██║░░██║██╔══██╗'
Write-Host '██║░░██║╚█████╔╝╚█████╔╝███████╗███████╗███████╗██║░░██║██║░░██║░░░██║░░░╚█████╔╝██║░░██║'
Write-Host '╚═╝░░╚═╝░╚════╝░░╚════╝░╚══════╝╚══════╝╚══════╝╚═╝░░╚═╝╚═╝░░╚═╝░░░╚═╝░░░░╚════╝░╚═╝░░╚═╝'
Write-Host ''
Write-Host '                            By Nick Benton (@ennnbeee)'
Write-Host '                                Version : 1.1.0'

#region Script
Write-Host ('Connected to Tenant {0} as account {1}' -f $graphDetails.TenantId, $graphDetails.Account) -ForegroundColor Green
Write-Host
Write-Host "Starting the 'Get Ready for Windows 11' Script..." -ForegroundColor Magenta
Write-Host
Write-Host 'The script will carry out the following:' -ForegroundColor Green
Write-Host "    - Capture all Windows Device or User objects from Entra ID, these are used for assigning an Extension Attribute ($extensionAttribute) used in the Dynamic Groups." -ForegroundColor Yellow
Write-Host "    - Start a Windows 11 Feature Update Readiness report for your selected build version of $featureUpdateBuild." -ForegroundColor Yellow
Write-Host "    - Capture and process the outcome of the Windows 11 Feature Update Readiness report for build version $featureUpdateBuild" -ForegroundColor Yellow
Write-Host "    - Based on the Risk level for the device, will assign a risk based flag to the Primary User or Device using Extension Attribute $extensionAttribute" -ForegroundColor Yellow
Write-Host
Write-Host 'The script can be run multiple times, as the Device Extension Attributes are overwritten with each run.' -ForegroundColor Cyan
Write-Host

Write-Host "Before proceding with the running of the script, please create Entra ID Dynamic $target Groups for each of the below risk levels, using the provided rule:" -ForegroundColor Green
Write-Host "    - Low Risk: ($target.$extensionAttribute -eq "LowRisk-W11-$featureUpdateBuild")" -ForegroundColor Yellow
Write-Host "    - Medium Risk: ($target.$extensionAttribute -eq "MediumRisk-W11-$featureUpdateBuild")" -ForegroundColor Yellow
Write-Host "    - High Risk: ($target.$extensionAttribute -eq "HighRisk-W11-$featureUpdateBuild")" -ForegroundColor Yellow
Write-Host "    - Not Ready: ($target.$extensionAttribute -eq "NotReady-W11-$featureUpdateBuild")" -ForegroundColor Yellow
Write-Host "    - Unknown: ($target.$extensionAttribute -eq "Unknown-W11-$featureUpdateBuild")" -ForegroundColor Yellow
Write-Host
Write-Warning 'Please review the above and confirm you are happy to continue.' -WarningAction Inquire
Write-Host
Write-Host "Getting $target objects and associated IDs from Entra ID..." -ForegroundColor Cyan
if ($target -eq 'user') {
    $entraUsers = Get-EntraIDObject -object User | Where-Object { $_.accountEnabled -eq 'true' -and $_.userType -eq 'Member' }
    Write-Host "Found $($entraUsers.Count) user objects and associated IDs from Entra ID." -ForegroundColor Green
    Write-Host
}
$entraDevices = Get-EntraIDObject -object Device | Where-Object { $_.operatingSystem -eq 'Windows' }
Write-Host "Found $($entraDevices.Count) Windows devices and associated IDs from Entra ID." -ForegroundColor Green
Write-Host

Write-Host "Checking for existing data in attribute $extensionAttribute in Entra ID..." -ForegroundColor Cyan

$attributeErrors = 0
$safeAttributes = @("LowRisk-W11-$featureUpdateBuild", "MediumRisk-W11-$featureUpdateBuild", "HighRisk-W11-$featureUpdateBuild", "NotReady-W11-$featureUpdateBuild", "Unknown-W11-$featureUpdateBuild")

$entraObjects = switch ($target) {
    'user' { $entraUsers }
    'device' { $entraDevices }
}

$extAttribute = switch ($target) {
    'user' { 'onPremisesExtensionAttributes' }
    'device' { 'extensionAttributes' }
}

foreach ($entraObject in $entraObjects) {

    $attribute = ($entraObject.$extAttribute | ConvertTo-Json | ConvertFrom-Json).$extensionAttribute

    if ($attribute -notin $safeAttributes) {
        if ($null -ne $attribute) {
            Write-Host "$($entraObject.displayName) already has a value of '$attribute' configured in $extensionAttribute" -ForegroundColor Yellow
            $attributeErrors = $attributeErrors + 1
        }
    }
}
if ($attributeErrors -gt 0) {
    Write-Host "Please review the objects reporting as having existing data in the selected attribute $extensionAttribute, and run the script using a different attribute selection." -ForegroundColor Red
    break
}

#region Feature Update Readiness
If ($featureUpdateBuild -eq '22H2') {
    $fu = 'NI22H2'
}
else {
    $fu = 'NI23H2'
}
$featureUpdateCreateJSON = @"
{
    "id": "MEMUpgradeReadinessDevice_00000000-0000-0000-0000-000000000001",
    "filter": "(TargetOS eq '$fu') and (DeviceScopesTag eq '00000')",
    "orderBy": [],
    "select": [
        "DeviceName",
        "DeviceManufacturer",
        "DeviceModel",
        "OSVersion",
        "ReadinessStatus",
        "SystemRequirements",
        "AppIssuesCount",
        "DriverIssuesCount",
        "AppOtherIssuesCount"
    ],
    "metadata": "TargetOS=>filterPicker=V2luZG93cyUyMDExJTIwLSUyMHZlcnNpb24lMjAyMkgy,DeviceScopesTag=>filterPicker=RGVmYXVsdA=="
}
"@

$featureUpdateGetJSON = @'
{
    "Id": "MEMUpgradeReadinessDevice_00000000-0000-0000-0000-000000000001",
    "Skip": 0,
    "Top": 50,
    "Search": "",
    "OrderBy": [],
    "Select": [
        "DeviceName",
        "DeviceManufacturer",
        "DeviceModel",
        "OSVersion",
        "ReadinessStatus",
        "SystemRequirements",
        "AppIssuesCount",
        "DriverIssuesCount",
        "AppOtherIssuesCount",
        "DeviceId",
        "AadDeviceId",
        "Ownership"
    ],
    "filter": ""
}
'@

Write-Host "Starting the Feature Update Readiness Report for Windows 11 $featureUpdateBuild..." -ForegroundColor Magenta
Write-Host

$startFeatureUpdateReport = New-ReportFeatureUpdateReadiness -JSON $featureUpdateCreateJSON
While ((Get-ReportFeatureUpdateReadiness -Id $startFeatureUpdateReport.id).status -ne 'completed') {
    Write-Host 'Waiting for the Feature Update report to finish processing...' -ForegroundColor Cyan
    Start-Sleep -Seconds $rndWait

}
Write-Host 'Feature Update Readiness report completed processing.' -ForegroundColor Green
Write-Host
Write-Host 'Getting Feature Update Report data...' -ForegroundColor Cyan
Write-Host

$featureUpdateReport = Get-ReportFeatureUpdateReadiness -JSON $featureUpdateGetJSON

Write-Host "Found Feature Update Report Details for $($featureUpdateReport.TotalRowCount) devices." -ForegroundColor Green
Write-Host
Write-Host "Processing data for 0 out of $($featureUpdateReport.TotalRowCount) devices..." -ForegroundColor Cyan
$featureUpdateReportDetails = @()
$featureUpdateReportDetails += $featureUpdateReport.Values

$i = 0
if ($($featureUpdateReport.TotalRowCount) -gt 50) {
    while ($i -le $($featureUpdateReport.TotalRowCount)) {
        $i = $i + 50
        $getNextJSON = @"
    {
        "Id": "MEMUpgradeReadinessDevice_00000000-0000-0000-0000-000000000001",
        "Skip": $i,
        "Top": 50,
        "Search": "",
        "OrderBy": [],
        "Select": [
            "DeviceName",
            "DeviceManufacturer",
            "DeviceModel",
            "OSVersion",
            "ReadinessStatus",
            "SystemRequirements",
            "AppIssuesCount",
            "DriverIssuesCount",
            "AppOtherIssuesCount",
            "DeviceId",
            "AadDeviceId",
            "Ownership"
        ],
        "filter": ""
    }
"@
        # Sleep to stop throttling issues
        Start-Sleep -Seconds $rndWait
        $featureUpdateReportNext = Get-ReportFeatureUpdateReadiness -JSON $getNextJSON
        Write-Host "Processing data for $i out of $($featureUpdateReport.TotalRowCount) devices..." -ForegroundColor Cyan
        $featureUpdateReportDetails += $featureUpdateReportNext.Values
    }
}
Write-Host "Processed data for $($featureUpdateReport.TotalRowCount) devices..." -ForegroundColor Green
Write-Host

Write-Host "Processing Windows 11 $featureUpdateBuild feature update readiness data for $($featureUpdateReport.TotalRowCount) devices..." -ForegroundColor Magenta
Write-Host

$reportArray = @()
foreach ($device in $featureUpdateReportDetails) {

    $riskState = switch ($device[10]) {
        '0' { "LowRisk-W11-$featureUpdateBuild" }
        '1' { "MediumRisk-W11-$featureUpdateBuild" }
        '2' { "HighRisk-W11-$featureUpdateBuild" }
        '3' { "NotReady-W11-$featureUpdateBuild" }
        '5' { "Unknown-W11-$featureUpdateBuild" }
    }

    $reportArray += [PSCustomObject]@{
        'AadDeviceId'         = $device[0]
        'AppIssuesCount'      = $device[1]
        'AppOtherIssuesCount' = $device[2]
        'DeviceId'            = $device[3]
        'DeviceManufacturer'  = $device[4]
        'DeviceModel'         = $device[5]
        'DeviceName'          = $device[6]
        'DriverIssuesCount'   = $device[7]
        'OSVersion'           = $device[8]
        'Ownership'           = $device[9]
        'ReadinessStatus'     = $device[10]
        'SystemRequirements'  = $device[11]
        'RiskState'           = $riskState
        'deviceObjectID'      = $(($entraDevices | Where-Object { $_.deviceid -eq $device[0] }).id)
        'userObjectID'        = $(($entraDevices | Where-Object { $_.deviceid -eq $device[0] }).id)
    }
}

Write-Host "Processed Windows 11 $featureUpdateBuild feature update readiness data for $($featureUpdateReport.TotalRowCount) devices." -ForegroundColor Green
Write-Host
#endregion Feature Update Readiness

#region Device Attributes
Write-Host "Starting the assignment of risk based extension attributes to $extensionAttribute" -ForegroundColor Magenta
Write-Host
Write-Warning 'Please confirm you are happy to continue.' -WarningAction Inquire
Write-Host
Write-Host "Assigning the Risk attributes to $extensionAttribute..." -ForegroundColor cyan
Write-Host
Foreach ($object in $reportArray) {
    if ($object.ReadinessStatus -ne '4') {

        $JSON = @"
        {
            "$extAttribute": {
                "$extensionAttribute": "$($object.RiskState)"
            }
        }
"@


        # Sleep to stop throttling issues
        Start-Sleep -Seconds $rndWait
        Add-ObjectAttribute -object Device -Id $object.deviceObjectID -JSON $JSON
        $riskColour = switch ($($object.RiskState)) {
            "LowRisk-W11-$featureUpdateBuild" { 'Green' }
            "MediumRisk-W11-$featureUpdateBuild" { 'Yellow' }
            "HighRisk-W11-$featureUpdateBuild" { 'Red' }
            "NotReady-W11-$featureUpdateBuild" { 'Red' }
            "Unknown-W11-$featureUpdateBuild" { 'Cyan' }
        }
        Write-Host "$($object.DeviceName) assigned risk tag $($object.RiskState) to $extensionAttribute for Windows 11 $featureUpdateBuild" -ForegroundColor $riskColour
    }
    Else {
        $JSON = @"
        {
            "extensionAttributes": {
                "$extensionAttribute": ""
            }
        }
"@
        Start-Sleep -Seconds $rndWait
        Add-ObjectAttribute -object Device -Id $object.deviceObjectID -JSON $JSON
        Write-Host "$($object.DeviceName) already updated to Windows 11 $featureUpdateBuild existing $extensionAttribute value cleared." -ForegroundColor White
    }
}
Write-Host
Write-Host "Completed the assignment of risk based device extension attributes to $extensionAttribute" -ForegroundColor Green
Write-Host
#endregion Device Attributes
Disconnect-MgGraph
#endregion Script
