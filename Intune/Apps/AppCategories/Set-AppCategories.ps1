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
Function Test-JSON() {
    <#
        .SYNOPSIS
        This function is used to test if the JSON passed to a REST Post request is valid
        .DESCRIPTION
        The function tests if the JSON passed to the REST Post is valid
        .EXAMPLE
        Test-JSON -JSON $JSON
        Test if the JSON is valid before calling the Graph REST interface
        .NOTES
        NAME: Test-JSON
        #>
    param (
        $JSON
    )
    try {
        $TestJSON = ConvertFrom-Json $JSON -ErrorAction Stop
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
Function Get-AppCategory() {
    [cmdletbinding()]
    $graphApiVersion = 'Beta'
    $Resource = 'deviceAppManagement/mobileAppCategories'
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
Function Add-AppCategory() {
    [cmdletbinding()]
    param
    (
        $Name
    )
    $graphApiVersion = 'Beta'
    $Resource = 'deviceAppManagement/mobileAppCategories'
    try {
        if ($Name -eq '' -or $null -eq $Name) {
            Write-Host 'No name specified, please specify valid Name for the App Category...' -f Red
            break
        }
        else {
            $Output = New-Object -TypeName psobject
            $Output | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.mobileAppCategory'
            $Output | Add-Member -MemberType NoteProperty 'displayName' -Value $Name
            $JSON = $Output | ConvertTo-Json -Depth 3
            Test-JSON -JSON $JSON
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            Invoke-RestMethod -Uri $uri -Headers $authToken -Method Post -Body $JSON -ContentType 'application/json'
        }
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
Function Get-MobileApps() {
    [cmdletbinding()]
    $graphApiVersion = 'Beta'
    $Resource = 'deviceAppManagement/mobileApps'
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
Function Get-MobileAppsCategory() {
    [cmdletbinding()]
    param
    (
        $Id
    )
    $graphApiVersion = 'Beta'
    $Resource = "deviceAppManagement/mobileApps/$Id/categories"
    try {
        if ($Id -eq '' -or $null -eq $Id) {
            Write-Host 'No Id specified, please specify valid Id for the Mobile App...' -f Red
            break
        }
        else {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
        }
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
Function Add-MobileAppCategory() {
    [cmdletbinding()]
    param
    (
        $Id,
        $CategoryId
    )
    $graphApiVersion = 'Beta'
    $Resource = "deviceAppManagement/mobileApps/$Id/categories/`$ref"
    try {
        if ($Id -eq '' -or $null -eq $Id) {
            Write-Host 'No Mobile App ID specified, please specify valid Id for the Mobile App ID...' -f Red
            break
        }
        elseif ($CategoryId -eq '' -or $null -eq $CategoryId) {
            Write-Host 'No App Category ID specified, please specify valid ID for the App Category...' -f Red
            break
        }
        else {
            $value = "https://graph.microsoft.com/$graphApiVersion/deviceAppManagement/mobileAppCategories/$CategoryId"
            $Output = New-Object -TypeName psobject
            $Output | Add-Member -MemberType NoteProperty -Name '@odata.id' -Value $value
            $JSON = $Output | ConvertTo-Json -Depth 3
            Test-JSON -JSON $JSON
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            Invoke-RestMethod -Uri $uri -Headers $authToken -Method Post -Body $JSON -ContentType 'application/json'
        }
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
Function Remove-MobileAppCategory() {
    [cmdletbinding()]
    param
    (
        $Id,
        $CategoryId
    )
    $graphApiVersion = 'Beta'
    $Resource = "deviceAppManagement/mobileApps/$Id/categories/$CategoryId/`$ref"
    try {
        if ($Id -eq '' -or $null -eq $Id) {
            Write-Host 'No Mobile App ID specified, please specify valid Id for the Mobile App ID...' -f Red
            break
        }
        elseif ($CategoryId -eq '' -or $null -eq $CategoryId) {
            Write-Host 'No App Category ID specified, please specify valid ID for the App Category...' -f Red
            break
        }
        else {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            Invoke-RestMethod -Uri $uri -Headers $authToken -Method Delete
        }
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
$sleep = '5'
Write-Host '********************************************************************************'
Write-Host '****    Welcome to the Endpoint Manager App Category and Assignment Tool    ****' -ForegroundColor Green
Write-Host '****    This Script will add new app categories and assign them             ****' -ForegroundColor Cyan
Write-Host '********************************************************************************'
Write-Host
Write-Host ' Please Choose one of the options below: ' -ForegroundColor Yellow
Write-Host
Write-Host ' (1) Upload a CSV of new App Categories...' -ForegroundColor Green
Write-Host
Write-Host ' (2) Upload a CSV of new App Categories and assign App Categories to Apps...' -ForegroundColor Green
Write-Host
Write-Host ' (3) Assign App Categories to Apps...' -ForegroundColor Green
Write-Host
Write-Host ' (4) Remove Assigned App Categories from Apps...' -ForegroundColor Green
Write-Host
Write-Host ' (E) EXIT SCRIPT ' -ForegroundColor Red
Write-Host
$Choice_Number = ''
$Choice_Number = Read-Host -Prompt 'Based on which option you want to run, please type 1, 2 or E to exit the script, then hit enter ' 
while ( !($Choice_Number -eq '1' -or $Choice_Number -eq '2' -or $Choice_Number -eq '3' -or $Choice_Number -eq '4' -or $Choice_Number -eq 'E')) {
    $Choice_Number = Read-Host -Prompt 'Invalid Option, Based on which option you want to run, please type 1, 2, 3, 4 or E to exit the test, then click enter ' 
}
if ($Choice_Number -eq 'E') { 
    Break
}
if ($Choice_Number -eq '1') {
    $Setting = 'Upload'
}
if ($Choice_Number -eq '2') {
    $Setting = 'Upload/Assign'
}
if ($Choice_Number -eq '3') {
    $Setting = 'Assign'
}
if ($Choice_Number -eq '4') {
    $Setting = 'Remove'
}
if ($Setting -like '*Upload*') {
    #region Add App Categories
    $CSVPath = Read-Host 'Please provide the path to the CSV file containing a list of App Categories e.g. C:\temp\appcategories.csv'
    if (!(Test-Path "$CSVPath")) {
        Write-Host "Import Path for CSV file doesn't exist" -ForegroundColor Red
        Write-Host "Script can't continue" -ForegroundColor Red
        Write-Host
        break
    }
    else {
        $AppCategories = Import-Csv -Path $CSVPath
    }
    $CurrentAppCategories = (Get-AppCategory).displayName
    foreach ($AppCategory in $AppCategories) {
        if ($AppCategory.Name -in $CurrentAppCategories) {
            Write-Host 'App Category '$AppCategory.Name' already exists...' -ForegroundColor Yellow
            Write-Host
        }
        else {
            Write-Host 'App Category will be created...' -ForegroundColor Yellow
            Write-Host
            try {
                Add-AppCategory -Name $AppCategory.Name | Out-Null
                Write-Host 'App Category '$AppCategory.Name' created...' -ForegroundColor Green
                Write-Host
            }
            catch {
                Write-Host 'App Category '$AppCategory.Name' not created...' -ForegroundColor Red
                Write-Host
            }
        }
    }
    #endregion
}
if ($Setting -like '*Assign*') {
    #region Assign App Categories
    Write-Host 'When prompted, wait for all Mobile Apps to load, then select the App or Apps you want to assign a Category. Use The ENTER Key or Mouse \ OK Button.' -ForegroundColor Yellow
    Write-Host
    Start-Sleep -Seconds $sleep
    $MobileApps = @(Get-MobileApps | Where-Object { (!($_.'@odata.type').Contains('managed')) -and (!($_.'@odata.type').Contains('android')) } | Select-Object '@odata.type', displayName, publisher, id | Out-GridView -PassThru -Title 'Select Mobile Apps...')
    Write-Host 'Wait for all App Categories to load, then select the Category or Categories you want to assign to an Application. Use The ENTER Key or Mouse \ OK Button.' -ForegroundColor Yellow
    Write-Host
    Start-Sleep -Seconds $sleep
    $AddAppCategories = @(Get-AppCategory | Select-Object displayName, id | Out-GridView -PassThru -Title 'Select Apps Categories...')
    Write-Host 'Starting assignment of Categories to Mobile Apps' -ForegroundColor Yellow
    Write-Host
    Write-Warning 'Please confirm you are happy to continue assigning categories to applications' -WarningAction Inquire
    foreach ($MobileApp in $MobileApps) {
        $AssignedAppCategories = Get-MobileAppsCategory -Id $MobileApp.id
        foreach ($AddAppCategory in $AddAppCategories) {
            if ($AddAppCategory.displayName -in $AssignedAppCategories.displayName) {
                Write-Host ''$AddAppCategory.displayName' category already assigned to '$MobileApp.displayName'' -ForegroundColor Yellow
                Write-Host
            }
            else {
                Write-Host 'Adding '$AddAppCategory.displayName' category to '$MobileApp.displayName'...' -ForegroundColor Yellow
                try {
                    Add-MobileAppCategory -Id $MobileApp.id -CategoryId $AddAppCategory.id
                    Write-Host 'Added '$AddAppCategory.displayName' category to '$MobileApp.displayName'...' -ForegroundColor Green
                    Write-Host
                }
                catch {
                    Write-Host 'Unable to add '$AddAppCategory.displayName' category to '$MobileApp.displayName'...' -ForegroundColor Red
                    Write-Host
                }
            }
        }
    }
    #endregion
}
if ($setting -eq 'Remove') {
    Write-Host 'When prompted, wait for all Mobile Apps to load, then select the App or Apps you want to remove categories from. Use The ENTER Key or Mouse \ OK Button.' -ForegroundColor Yellow
    Write-Host
    Start-Sleep -Seconds $sleep
    $MobileApps = @(Get-MobileApps | Where-Object { (!($_.'@odata.type').Contains('managed')) -and (!($_.'@odata.type').Contains('android')) } | Select-Object '@odata.type', displayName, publisher, id | Out-GridView -PassThru -Title 'Select Mobile Apps...')
    foreach ($MobileApp in $MobileApps) {
        $AssignedAppCategories = Get-MobileAppsCategory -Id $MobileApp.id
        If (!$AssignedAppCategories) {
            Write-Host 'App '$MobileApp.displayName' has no assigned App Categories...' -ForegroundColor Yellow
            Write-Host
        }
        Else {
            Write-Host 'The following App Categories for App '$MobileApp.displayName' will be removed...' -ForegroundColor Yellow
            $AssignedAppCategories.displayName
            Write-Host
            Start-Sleep -Seconds $sleep
            foreach ($AssignedAppCategory in $AssignedAppCategories) {
                Try {
                    Remove-MobileAppCategory -Id $MobileApp.id -CategoryId $AssignedAppCategory.id
                    Write-Host 'App Category '$AssignedAppCategory.displayName' removed from App '$MobileApp.displayName'' -ForegroundColor Green
                    Write-Host
                }
                Catch {
                    Write-Host 'Unable to remove App Category '$AssignedAppCategory.displayName' from App '$MobileApp.displayName'' -ForegroundColor Red
                    Write-Host
                }
            }
        }
    }
}