[CmdletBinding()]
param(

    [Parameter(Mandatory = $true)]
    [ValidateSet('Update', 'Remove')]
    [String]$Mode

)

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
Function Get-DeviceAAD() {

    [cmdletbinding()]

    param
    (

    )

    $graphApiVersion = 'beta'
    $Resource = 'devices'

    try {

        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
        $GraphResults = Invoke-MgGraphRequest -Method GET -Uri $uri

        $Results = @()
        $Results += $GraphResults.value

        $Pages = $GraphResults.'@odata.nextLink'
        while ($null -ne $Pages) {

            $Additional = Invoke-MgGraphRequest -Method GET -Uri $Pages

            if ($Pages) {
                $Pages = $Additional.'@odata.nextLink'
            }
            $Results += $Additional.value
        }
        $Results
    }
    catch {
        $exs = $Error.ErrorDetails
        $ex = $exs[0]
        Write-Host "Response content:`n$ex" -f Red
        Write-Host
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Message)"
        Write-Host
        break
    }
}
Function Add-DeviceAttribute() {

    [cmdletbinding()]

    param
    (
        [parameter(Mandatory = $true)]
        $JSON,

        [parameter(Mandatory = $true)]
        $deviceID
    )

    $graphApiVersion = 'Beta'
    $Resource = "devices/$deviceID"

    try {
        Test-Json -Json $JSON
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        Invoke-MgGraphRequest -Uri $uri -Method Patch -Body $JSON -ContentType 'application/json'
    }
    catch {
        $exs = $Error.ErrorDetails
        $ex = $exs[0]
        Write-Host "Response content:`n$ex" -f Red
        Write-Host
        Write-Error "Request to $Uri failed with HTTP Status $($ex.Message)"
        Write-Host
        break
    }
}
#endregion Functions

Try {
    Connect-MgGraph -Scopes 'Device.ReadWrite.All'
}

Catch{
    Write-Host 'Unable to connect to Graph...' -ForegroundColor Red
    Break
}

#endregion

If ($Mode -eq 'Update') {
    $attributeValue = Read-Host 'Enter in the attribute value to be assigned to devices...'
}
else {
    Clear-Variable attributeValue
}

$Devices = @(Get-DeviceAAD | Select-Object displayName, operatingSystem, manufacturer, model, id, deviceId  | Out-GridView -PassThru -Title 'Select Devices to update extension attributes...')

$extensionAttributes = @()
for ($i = 1; $i -le 15; $i++) {
    $extensionAttributes += 'extensionAttribute' + $i
}
$Attribute = @($extensionAttributes | Out-GridView -PassThru -Title 'Select only one attribute you wish to update...')

while ($Attribute.count -gt 1) {
    Write-Host 'Only select one attribute to update' -ForegroundColor Yellow
    $Attribute = @($extensionAttributes | Out-GridView -PassThru -Title 'Select only one attribute you wish to update...')
}

if ($Devices.count -ne 0) {
    if ($Mode -eq 'Update') {
        Write-Host "$($Devices.count) devices have been selected and will have the data in $Attribute updated to $attributeValue" -ForegroundColor Cyan
    }
    else {
        Write-Host "$($Devices.count) devices have been selected and will have the data in $Attribute removed." -ForegroundColor Cyan
    }
    Write-Warning 'Please confirm you are happy with these settings before continuing' -WarningAction Inquire

    foreach ($Device in $Devices) {

        $JSON = @"
    {
        "extensionAttributes": {
            "$Attribute": "$attributeValue"
        }
    }
"@

        Add-DeviceAttribute -deviceID $device.id -JSON $JSON
        Write-Host "Successfully updated $Attribute for device object $($Device.displayName)" -ForegroundColor Green
    }
    #Disconnect-MgGraph
}
else {
    Write-Host 'Script Cancelled due to zero devices selected' -ForegroundColor Red
    break
}