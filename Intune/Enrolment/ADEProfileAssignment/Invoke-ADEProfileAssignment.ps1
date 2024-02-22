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
Function Get-ADEEnrolmentToken() {

    [cmdletbinding()]


    $graphApiVersion = 'Beta'
    $Resource = 'deviceManagement/depOnboardingSettings'

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
Function Get-ADEEnrolmentProfile() {

    Param(
        [Parameter(Mandatory = $true)]
        $TokenID
    )

    $graphApiVersion = 'Beta'
    $Resource = "deviceManagement/depOnboardingSettings/$TokenID/enrollmentProfiles"

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
Function Add-ADEEnrolmentProfileAssignment() {

    Param(
        [Parameter(Mandatory = $true)]
        $Id,
        [Parameter(Mandatory = $true)]
        $ProfileID,
        [Parameter(Mandatory = $true)]
        $DeviceSerials
    )

    $graphApiVersion = 'Beta'
    $Resource = "deviceManagement/depOnboardingSettings/$Id/enrollmentProfiles('$ProfileID')/updateDeviceProfileAssignment"

    $Output = New-Object -TypeName psobject
    $Output | Add-Member -MemberType NoteProperty -Name 'deviceIds' -Value $DeviceSerials
    $JSON = $Output | ConvertTo-Json -Depth 3

    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        Invoke-RestMethod -Uri $uri -Headers $authToken -Method Post -Body $JSON -ContentType 'application/json'
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

#region Script
$Sleep = '1'
Write-Host '******************************************************************************'
Write-Host '****    Welcome to the Intune Apple ADE Device Profile Assignment Tool    ****' -ForegroundColor Green
Write-Host '****    This Script will import device serials and assign an ADE profile  ****' -ForegroundColor Cyan
Write-Host '******************************************************************************'
Write-Host
#region Authentication
if ($global:authToken) {
    $DateTime = (Get-Date).ToUniversalTime()
    $TokenExpires = ($authToken.ExpiresOn.datetime - $DateTime).Minutes

    if ($TokenExpires -le 0) {
        Write-Host 'Authentication Token expired' $TokenExpires 'minutes ago' -ForegroundColor Yellow
        if ($null -eq $User -or $User -eq '') {
            $User = Read-Host -Prompt 'Please specify your user principal name for Azure Authentication'
        }
        $global:authToken = Get-AuthTokenMSAL -User $User
        Write-Host 'Connected to Graph API' -ForegroundColor Green

    }
    Else {
        Write-Host 'Connected to Graph API' -ForegroundColor Green
    }
}
else {

    if ($null -eq $User -or $User -eq '') {
        $User = Read-Host -Prompt 'Please specify your user principal name for Azure Authentication'
    }
    $global:authToken = Get-AuthTokenMSAL -User $User
    Write-Host 'Connected to Graph API' -ForegroundColor Green
}

#endregion
Write-Host
$CSVPath = Read-Host 'Please provide the path to the CSV file containing a list of Serial Numbers and ADE Profile Names e.g. C:\temp\ADEDevices.csv'
if (!(Test-Path "$CSVPath")) {
    Write-Host "Import Path for CSV file doesn't exist" -ForegroundColor Red
    Write-Host "Script can't continue" -ForegroundColor Red
    Write-Host
    break
}
Start-Sleep -Seconds $Sleep
Write-host "Importing Devices..." -ForegroundColor Cyan
Write-Host
Try {
    $Devices = Import-Csv -Path $CSVPath
    Write-Host "Imported Device Serials and Assignment Profiles" -ForegroundColor Green
    Write-Host
}
Catch {
    Write-Host "Unable to Import CSV " -ForegroundColor Red
    Write-Host
    Break
}
Start-Sleep -Seconds $Sleep
Write-Host "Processing Enrolment Profiles and Device Serials..." -ForegroundColor Cyan
Write-Host
$DeviceProfiles = @()
foreach ($Device in $Devices) {
    $DeviceProfiles += $Device.EnrolmentProfile
}

$UniqueDeviceProfiles = $DeviceProfiles | Get-Unique
$Assignments = @{}
foreach ($UniqueDeviceProfile in $UniqueDeviceProfiles){
    $Assignments[$UniqueDeviceProfile] = @()
}
foreach ($Device in $Devices) {
    $Assignments["$($Device.EnrolmentProfile)"] += $Device.Serial
}
Start-Sleep -Seconds $Sleep
Write-Host "Completed processing Enrolment Profiles and Device Serials" -ForegroundColor Green
Write-Host

Write-host "Getting Apple Enrolment Token..." -ForegroundColor Cyan
Write-Host
Try {

    $Token = Get-ADEEnrolmentToken
    Write-Host "Found Token: $($Token.tokenName) in Intune" -ForegroundColor Green
    Write-Host
}
Catch {
    Write-Host "Unable to retreive the Apple Enrolment Token" -ForegroundColor Red
    Write-Host
    Break
}

Start-Sleep -Seconds $Sleep
foreach ($Assignment in $Assignments.GetEnumerator()) {
    Write-Host "Preparing to assign Enrolment Profiles to devices..." -ForegroundColor Cyan
    Write-Host
    Write-Host "Enrolment Profile: $($Assignment.Name)" -ForegroundColor Yellow
    Write-Host
    Write-Host "Devices: $($Assignment.Value)" -ForegroundColor Yellow
    Write-Host
    Write-Warning 'Please confirm you are happy to continue assigning the Enrolment Profile to the devices' -WarningAction Inquire
    Try {
        Write-Host "Assigning Enrolment Profile to devices..." -ForegroundColor Cyan
        Write-Host
        Try{
            $EnrolmentProfile = Get-ADEEnrolmentProfile -TokenID $Token.id | Where-Object { ($_.displayName -eq $Assignment.Name) }
            Try {
                Add-ADEEnrolmentProfileAssignment -TokenID $Token.id -ProfileID $EnrolmentProfile.id -DeviceSerial $Assignment.Value
                Write-Host "Enrolment Profile $($Assignment.Name) successfully assigned to devices: $($Assignment.Value)" -ForegroundColor Green
                Write-Host
                Start-Sleep -Seconds $Sleep
            }
            Catch {
                Write-Host "Unable to assign devices to Enrolment Profile $($Assignment.Name)" -ForegroundColor Red
                Write-Host
            }
        }
        Catch{
            Write-Host "Unable to find Enrolment Profile in Intune with name: $($Assignment.Name)" -ForegroundColor Red
            Write-Host
        }
    }
    Catch {
        Write-Host "Unable to assign Enrolment Profiles to Devices" -ForegroundColor Red
        Write-Host
    }
}





