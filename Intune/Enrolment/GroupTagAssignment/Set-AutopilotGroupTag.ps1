[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('CSV', 'Online')]
    [string]$Method,
    [Parameter(Mandatory = $true)]
    [string]$DefaultGroupTag
)

## Functions
Function Get-AuthTokenMSAL {

    <#
    .SYNOPSIS
    This function is used to authenticate with the Graph API REST interface
    .DESCRIPTION
    The function authenticate with the Graph API Interface with the tenant name
    .EXAMPLE
    Get-AuthTokenMSAL
    Authenticates you with the Graph API interface using MSAL.PS module
    .NOTES
    NAME: Get-AuthTokenMSAL
    #>
    
    [cmdletbinding()]
    
    param
    (
        [Parameter(Mandatory = $true)]
        $User
    )
    
    $userUpn = New-Object 'System.Net.Mail.MailAddress' -ArgumentList $User
    if ($userUpn.Host -like '*onmicrosoft.com*') {
        $tenant = Read-Host -Prompt 'Please specify your Tenant name i.e. company.com'
        Write-Host
    }
    else {
        $tenant = $userUpn.Host
    }
    
    Write-Host 'Checking for MSAL.PS module...'
    $MSALModule = Get-Module -Name 'MSAL.PS' -ListAvailable
    if ($null -eq $MSALModule) {
        Write-Host
        Write-Host 'MSAL.PS Powershell module not installed...' -f Red
        Write-Host "Install by running 'Install-Module MSAL.PS -Scope CurrentUser' from an elevated PowerShell prompt" -f Yellow
        Write-Host "Script can't continue..." -f Red
        Write-Host
        exit
    }
    if ($MSALModule.count -gt 1) {
        $Latest_Version = ($MSALModule | Select-Object version | Sort-Object)[-1]
        $MSALModule = $MSALModule | Where-Object { $_.version -eq $Latest_Version.version }
        # Checking if there are multiple versions of the same module found
        if ($MSALModule.count -gt 1) {
            $MSALModule = $MSALModule | Select-Object -Unique
        }
    }
        
    $ClientId = 'd1ddf0e4-d672-4dae-b554-9d5bdfd93547'
    $RedirectUri = 'urn:ietf:wg:oauth:2.0:oob'
    $Authority = "https://login.microsoftonline.com/$Tenant"
    
    try {
        Import-Module $MSALModule.Name
        if ($PSVersionTable.PSVersion.Major -ne 7) {
            $authResult = Get-MsalToken -ClientId $ClientId -Interactive -RedirectUri $RedirectUri -Authority $Authority
        }
        else {
            $authResult = Get-MsalToken -ClientId $ClientId -Interactive -RedirectUri $RedirectUri -Authority $Authority -DeviceCode
        }
        # If the accesstoken is valid then create the authentication header
        if ($authResult.AccessToken) {
            # Creating header for Authorization token
            $authHeader = @{
                'Content-Type'  = 'application/json'
                'Authorization' = 'Bearer ' + $authResult.AccessToken
                'ExpiresOn'     = $authResult.ExpiresOn
            }
            return $authHeader
        }
        else {
            Write-Host
            Write-Host 'Authorization Access Token is null, please re-run authentication...' -ForegroundColor Red
            Write-Host
            break
        }
    }
    catch {
        Write-Host $_.Exception.Message -f Red
        Write-Host $_.Exception.ItemName -f Red
        Write-Host
        break
    }
}
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
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
        
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
        Invoke-RestMethod -Uri $uri -Headers $authToken -Method Post -Body $JSON -ContentType 'application/json'
        Write-Host "Successfully added '$GroupTag' to device" -ForegroundColor Green
        
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

#region Authentication
# Checking if authToken exists before running authentication
if ($global:authToken) {

    # Setting DateTime to Universal time to work in all timezones
    $DateTime = (Get-Date).ToUniversalTime()

    # If the authToken exists checking when it expires
    $TokenExpires = ($authToken.ExpiresOn.datetime - $DateTime).Minutes

    if ($TokenExpires -le 0) {

        Write-Host 'Authentication Token expired' $TokenExpires 'minutes ago' -ForegroundColor Yellow
        Write-Host

        # Defining User Principal Name if not present

        if ($null -eq $User -or $User -eq '') {

            $User = Read-Host -Prompt 'Please specify your user principal name for Azure Authentication'
            Write-Host

        }

        $global:authToken = Get-AuthTokenMSAL -User $User

    }
}

# Authentication doesn't exist, calling Get-AuthToken function

else {

    if ($null -eq $User -or $User -eq '') {

        $User = Read-Host -Prompt 'Please specify your user principal name for Azure Authentication'
        Write-Host

    }

    # Getting the authorization token
    $global:authToken = Get-AuthTokenMSAL -User $User
    Write-Host 'Connected to Graph API' -ForegroundColor Green
    Write-Host
}

#endregion

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