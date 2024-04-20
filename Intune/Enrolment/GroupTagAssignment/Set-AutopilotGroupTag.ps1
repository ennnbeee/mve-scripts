[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [String]$tenantId,

    [Parameter(Mandatory = $false)]
    [String[]]$scopes = 'DeviceManagementConfiguration.Read.All,DeviceManagementManagedDevices.ReadWrite.All,DeviceManagementConfiguration.ReadWrite.All',

    [Parameter(Mandatory = $true)]
    [ValidateSet('CSV', 'Online')]
    [string]$Method,

    [Parameter(Mandatory = $true)]
    [string]$DefaultGroupTag
)

## Functions
Function Get-AutopilotDevices() {

    <#
    .SYNOPSIS
    This function is used to get autopilot devices via the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any autopilot devices
    .EXAMPLE
    Get-AutopilotDevices
    Returns any autopilot devices
    .NOTES
    NAME: Get-AutopilotDevices
    #>

    $graphApiVersion = 'Beta'
    $Resource = 'deviceManagement/windowsAutopilotDeviceIdentities'

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-MgGraphRequest-Uri $uri -Method Get).Value

    }

    catch {

        Write-Error $Error[0].ErrorDetails.Message
        break

    }

}

Function Set-AutopilotDevice() {

    <#
    .SYNOPSIS
    This function is used to set autopilot devices properties via the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and sets autopilot device properties
    .EXAMPLE
    Set-AutopilotDevice
    Returns any autopilot devices
    .NOTES
    NAME: Set-AutopilotDevice
    #>

    [CmdletBinding()]
    param(
        $Id,
        $GroupTag
    )

    $graphApiVersion = 'Beta'
    $Resource = "deviceManagement/windowsAutopilotDeviceIdentities/$Id/updateDeviceProperties"

    try {

        if (!$id) {
            Write-Host 'No Autopilot device Id specified, specify a valid Autopilot device Id' -f Red
            break
        }

        if (!$GroupTag) {
            $GroupTag = Read-Host 'No Group Tag specified, specify a Group Tag'
        }

        $Autopilot = New-Object -TypeName psobject
        $Autopilot | Add-Member -MemberType NoteProperty -Name 'groupTag' -Value $GroupTag

        $JSON = $Autopilot | ConvertTo-Json -Depth 3
        # POST to Graph Service
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        Invoke-MgGraphRequest-Uri $uri -Method Post -Body $JSON -ContentType 'application/json'
        Write-Host "Successfully added '$GroupTag' to device" -ForegroundColor Green

    }

    catch {

        Write-Error $Error[0].ErrorDetails.Message
        break

    }

}

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
        Connect-MgGraph -Scopes $scopes -UseDeviceAuthentication -TenantId $tenantId
    }

    $graphDetails = Get-MgContext
    if ($null -eq $graphDetails) {
        Write-Host "Not connected to Graph, please review any errors and try to run the script again' cmdlet." -ForegroundColor Red
        break
    }
}
#endregion authentication

# Script Start
# Get Devices
if ($Method -eq 'CSV') {
    $CSVPath = Read-Host 'Please provide the path to the CSV file containing a list of device serial numbers and new Group Tag  e.g. C:\temp\devices.csv'

    if (!(Test-Path "$CSVPath")) {
        Write-Host "Import Path for CSV file doesn't exist" -ForegroundColor Red
        Write-Host "Script can't continue" -ForegroundColor Red
        Write-Host
        break

    }
    else {
        $AutopilotDevices = Import-Csv -Path $CSVPath
    }
}
elseif ($Method -eq 'Online') {
    Write-Host 'Getting all Autopilot devices without a Group Tag' -ForegroundColor Cyan
    $AutopilotDevices = Get-AutopilotDevices | Where-Object { ($null -eq $_.groupTag) -or ($_.groupTag) -eq '' }
}

# Sets Group Tag
foreach ($AutopilotDevice in $AutopilotDevices) {

    $id = $AutopilotDevice.id
    if (!$id) {
        Write-Host 'No Autopilot Device Id, getting Id from Graph' -ForegroundColor Cyan
        $id = (Get-AutopilotDevices | Where-Object { ($_.serialNumber -eq $AutopilotDevice.serialNumber) }).id
        Write-Host "ID:'$Id' found for device with serial '$($AutopilotDevice.Serialnumber)'" -ForegroundColor Green
    }

    if ($Method -eq 'CSV') {
        $GroupTag = $AutopilotDevice.groupTag
        if (!$GroupTag) {
            Write-Host 'No Autopilot Device Group Tag found in CSV' -ForegroundColor Cyan
            $GroupTag = Read-Host 'Please enter the group tag for device with serial '$AutopilotDevice.serialNumber' now:'
        }
    }

    elseif ($Method -eq 'Online') {
        $GroupTag = $DefaultGroupTag
    }

    try {
        Set-AutopilotDevice -id $id -groupTag $GroupTag
        Write-Host "Group tag: '$GroupTag' set for device with serial '$($AutopilotDevice.Serialnumber)'" -ForegroundColor Green
    }
    catch {
        Write-Host "Group tag: '$GroupTag' not set for device with serial '$($AutopilotDevice.Serialnumber)'" -ForegroundColor Red
    }


}