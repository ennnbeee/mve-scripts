#region Functions
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
Function Get-ManagedDevices() {
    
    <#
    .SYNOPSIS
    This function is used to get Intune Managed Devices from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any Intune Managed Device
    .EXAMPLE
    Get-ManagedDevices
    Returns all managed devices but excludes EAS devices registered within the Intune Service
    .EXAMPLE
    Get-ManagedDevices -IncludeEAS
    Returns all managed devices including EAS devices registered within the Intune Service
    .NOTES
    NAME: Get-ManagedDevices
    #>
    
    [cmdletbinding()]
    
    param
    (
        [switch]$IncludeEAS,
        [switch]$ExcludeMDM
    )
    
    # Defining Variables
    $graphApiVersion = 'beta'
    $Resource = 'deviceManagement/managedDevices'
    
    try {
    
        $Count_Params = 0
    
        if ($IncludeEAS.IsPresent) { $Count_Params++ }
        if ($ExcludeMDM.IsPresent) { $Count_Params++ }
            
        if ($Count_Params -gt 1) {
    
            Write-Warning 'Multiple parameters set, specify a single parameter -IncludeEAS, -ExcludeMDM or no parameter against the function'
            Write-Host
            break
    
        }
            
        elseif ($IncludeEAS) {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource"
    
        }
    
        elseif ($ExcludeMDM) {
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource`?`$filter=managementAgent eq 'eas'"
    
        }
            
        else {
        
            $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource`?`$filter=managementAgent eq 'mdm' and managementAgent eq 'easmdm'"
    
        }
    
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
Function Set-ManagedDeviceOwnership() {
    
    [cmdletbinding()]
    
    param
    (
        $id,
        $ownertype
    )
    $graphApiVersion = 'Beta'
    $Resource = 'deviceManagement/managedDevices'
    
    try {
    
        if ($id -eq '' -or $null -eq $id) {
    
            Write-Host 'No Device id specified, please provide a device id...' -f Red
            break
    
        }
            
        if ($ownerType -eq '' -or $null -eq $ownerType) {
    
            Write-Host 'No ownerType parameter specified, please provide an ownerType. Supported value personal or company...' -f Red
            Write-Host
            break
    
        }
    
        $Output = New-Object -TypeName psobject
        $Output | Add-Member -MemberType NoteProperty -Name 'ownerType' -Value $ownerType

        $JSON = $Output | ConvertTo-Json -Depth 3

                
        # Send Patch command to Graph to change the ownertype
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource/$ID"
        Invoke-RestMethod -Uri $uri -Headers $authToken -Method Patch -Body $Json -ContentType 'application/json'

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
Function Get-DeviceGroup() {

    [cmdletbinding()]
    
    param
    (
        [string]$GroupName
    )

    # Defining Variables
    $graphApiVersion = 'v1.0'
    $Resource = 'groups'
    
    try {
        
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource`?`$filter=displayName eq '$GroupName'"

    
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
Function Get-DeviceGroupMembers() {

    [cmdletbinding()]
    
    param
    (
        [string]$id
    )

    # Defining Variables
    $graphApiVersion = 'v1.0'
    $Resource = 'groups'
    
    try {
        
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource/$id/members"

    
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
#endregion
    
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
    
#region Script
    
Write-Host '****************************************************************************'

Write-Host '****    Welcome to the Endpoint Manager Device Ownership Converter Tool ****' -ForegroundColor Green
Write-Host '****    This Script will change the ownership of devices to Corporate   ****' -ForegroundColor Cyan

Write-Host '****************************************************************************'

Write-Host

Write-Host ' Please Choose one of the options below: ' -ForegroundColor Yellow
Write-Host
Write-Host ' (1) Upload a CSV of device serial numbers to be converted... ' -ForegroundColor Green
Write-Host
Write-Host ' (2) Specify an Azure AD group of devices to be converted... ' -ForegroundColor Green
Write-Host
Write-Host ' (E) EXIT SCRIPT ' -ForegroundColor Red
Write-Host
$Choice_Number = ''
$Choice_Number = Read-Host -Prompt 'Based on which option you want to run, please type 1, 2 or E to exit the script, then hit enter ' 

while ( !($Choice_Number -eq '1' -or $Choice_Number -eq '2' -or $Choice_Number -eq 'E')) {

    $Choice_Number = Read-Host -Prompt 'Invalid Option, Based on which option you want to run, please type 1, 2 or E to exit the test, then click enter ' 

}

if ($Choice_Number -eq 'E') { 
    Break
}
if ($Choice_Number -eq '1') {
    $CSVPath = Read-Host 'Please provide the path to the CSV file containing a list of device serial numbers e.g. C:\temp\devices.csv'

    if (!(Test-Path "$CSVPath")) {
        Write-Host "Import Path for CSV file doesn't exist" -ForegroundColor Red
        Write-Host "Script can't continue" -ForegroundColor Red
        Write-Host
        break
        
    }
    else {
        $Devices = Import-Csv -Path $CSVPath
    }
}
if ($Choice_Number -eq '2') { 
    $Group = Read-Host 'Please provide the name of the group containing members you want to convert'
    try {
        $id = (Get-DeviceGroup -GroupName "$Group").id

        $Devices = Get-DeviceGroupMembers -id $id
    }
    catch {
        Write-Host 'Unable to find the device group' -ForegroundColor Red
        Write-Host "Script can't continue" -ForegroundColor Red
        Write-Host
        break
    }

}

if (!$Devices) {
    Write-Host 'No devices found, please run the script again...' -ForegroundColor Red
    Write-Host
    Break
}


foreach ($Device in $Devices) {
    If ($Device.SerialNumber) {
        try {
            $ManagedDevice = Get-ManagedDevices | Where-Object { $_.serialnumber -eq $Device.SerialNumber }
            Write-Host 'Found '$ManagedDevice.DeviceName' with ownership '$ManagedDevice.ownerType'' -ForegroundColor Cyan
        }
        catch {
            Write-Host 'Unable to find device with serial number '$Device.SerialNumber'' -ForegroundColor Yellow
        }
        
    }
    Else {
        try {
            $ManagedDevice = Get-ManagedDevices | Where-Object { $_.azureADDeviceId -eq $Device.deviceId }
            Write-Host 'Found '$ManagedDevice.DeviceName' with ownership '$ManagedDevice.ownerType'' -ForegroundColor Cyan
        }
        catch {
            Write-Host 'Unable to find device with name '$Device.DisplayName'' -ForegroundColor Yellow
        }
        
    }
    try {
        Set-ManagedDeviceOwnership -id $ManagedDevice.id -ownertype company
        Write-Host 'Device Name: '$ManagedDevice.deviceName' ownership changed from '$ManagedDevice.ownerType' to corporate.' -ForegroundColor Green
    }
    catch {
        Write-Host 'Unable change ownwership of device: '$ManagedDevice.deviceName'' -ForegroundColor Yellow
    }
}

#endregion