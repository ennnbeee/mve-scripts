function Get-AuthToken {

    <#
    .SYNOPSIS
    This function is used to authenticate with the Graph API REST interface
    .DESCRIPTION
    The function authenticate with the Graph API Interface with the tenant name
    .EXAMPLE
    Get-AuthToken
    Authenticates you with the Graph API interface
    .NOTES
    NAME: Get-AuthToken
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
    
    
    Write-Host 'Checking for AzureAD module...'
    
    $AadModule = Get-Module -Name 'AzureADPreview' -ListAvailable
    
    if ($null -eq $AadModule) {
    
        Write-Host 'AzureAD PowerShell module not found, looking for AzureADPreview'
        $AadModule = Get-Module -Name 'AzureADPreview' -ListAvailable
    
    }
    
    if ($null -eq $AadModule) {
        Write-Host
        Write-Host 'AzureAD Powershell module not installed...' -f Red
        Write-Host "Install by running 'Install-Module AzureAD' or 'Install-Module AzureADPreview' from an elevated PowerShell prompt" -f Yellow
        Write-Host "Script can't continue..." -f Red
        Write-Host
        exit
    }
    
    # Getting path to ActiveDirectory Assemblies
    # If the module count is greater than 1 find the latest version
    
    if ($AadModule.count -gt 1) {
    
        $Latest_Version = ($AadModule | Select-Object version | Sort-Object)[-1]
    
        $aadModule = $AadModule | Where-Object { $_.version -eq $Latest_Version.version }
    
        # Checking if there are multiple versions of the same module found
    
        if ($AadModule.count -gt 1) {
    
            $aadModule = $AadModule | Select-Object -Unique
    
        }
    
        $adal = Join-Path $AadModule.ModuleBase 'Microsoft.IdentityModel.Clients.ActiveDirectory.dll'
        $adalforms = Join-Path $AadModule.ModuleBase 'Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll'
            
    
    }
    
    else {
    
        $adal = Join-Path $AadModule.ModuleBase 'Microsoft.IdentityModel.Clients.ActiveDirectory.dll'
        $adalforms = Join-Path $AadModule.ModuleBase 'Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll'
    
    }
    
    [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
    
    [System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null
    
    $clientId = 'd1ddf0e4-d672-4dae-b554-9d5bdfd93547'
    
    $redirectUri = 'urn:ietf:wg:oauth:2.0:oob'
    
    $resourceAppIdURI = 'https://graph.microsoft.com'
    
    $authority = "https://login.microsoftonline.com/$Tenant"
    
    try {
    
        $authContext = New-Object 'Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext' -ArgumentList $authority
    
        # https://msdn.microsoft.com/en-us/library/azure/microsoft.identitymodel.clients.activedirectory.promptbehavior.aspx
        # Change the prompt behaviour to force credentials each time: Auto, Always, Never, RefreshSession
    
        $platformParameters = New-Object 'Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters' -ArgumentList 'Auto'

        $userId = New-Object 'Microsoft.IdentityModel.Clients.ActiveDirectory.UserIdentifier' -ArgumentList ($User, 'OptionalDisplayableId')
             
        $authResult = $authContext.AcquireTokenAsync($resourceAppIdURI, $clientId, $redirectUri, $platformParameters, $userId).Result
    
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
function Get-AuthTokenMSAL {

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
           
        $authResult = Get-MsalToken -ClientId $ClientId -Interactive -RedirectUri $RedirectUri -Authority $Authority -DeviceCode
    
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

Function Get-DeviceCompliancePolicy() {

    <#
    .SYNOPSIS
    This function is used to get device compliance policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets any device compliance policies
    .EXAMPLE
    Get-DeviceCompliancePolicy
    Returns any device compliance policies configured in Intune
    .EXAMPLE
    Get-DeviceCompliancePolicy -Android
    Returns any device compliance policies for Android configured in Intune
    .EXAMPLE
    Get-DeviceCompliancePolicy -iOS
    Returns any device compliance policies for iOS configured in Intune
    .NOTES
    NAME: Get-DeviceCompliancePolicy
    #>
    
    [cmdletbinding()]
    
  
    $graphApiVersion = 'Beta'
    $Resource = 'deviceManagement/deviceCompliancePolicies'
    
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

Function Update-DeviceCompliancePolicy() {

    <#
    .SYNOPSIS
    This function is used to update device compliance policies from the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and updates device compliance policies
    .EXAMPLE
    Update-DeviceCompliancePolicy -id -JSON
    Updates a device compliance policies configured in Intune
    .NOTES
    NAME: Update-DeviceCompliancePolicy
    #>
    
    [cmdletbinding()]
    param
    (
        $Id,
        $JSON
    )
  
    $graphApiVersion = 'Beta'
    $Resource = "deviceManagement/deviceCompliancePolicies/$id"
    
    try {

        if (!$Id) {

            Write-Host 'No Compliance Policy Id specified, specify a valid Compliance Policy Id' -f Red
            break
    
        }
    
        if ($JSON -eq '' -or $null -eq $JSON) {

            Write-Host 'No JSON specified, please specify valid JSON for the Compliance Policy...' -f Red
    
        }
    
        else {
    
            Test-Json -Json $JSON
    
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            Invoke-RestMethod -Uri $uri -Headers $authToken -Method Patch -Body $JSON -ContentType 'application/json'
            Write-Host
            Write-Host 'Successfully Updated Compliance Policy' -ForegroundColor Green
    
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

Function Get-LatestDefenderPlatformUpdate() {

    try {

        $uri = 'https://support.microsoft.com/en-us/feed/atom/5d4715e7-a9c9-378e-3f83-fd410db4ef0a'
        [xml]$Updates = (Invoke-WebRequest -Uri $uri -UseBasicParsing -ContentType 'application/xml').Content -replace '[^\x09\x0A\x0D\x20-\xD7FF\xE000-\xFFFD\x10000-x10FFFF]', ''
        $DefenderUpdateUri = @()
        foreach ($Update in $Updates.feed.entry) {
            if ($Update.title.'#text' -like '*platform*') {
                $DefenderUpdateUri += $Update.link.href
            }
        }

        $DefenderPlatformUpdate = Invoke-WebRequest -Uri $($DefenderUpdateUri[0])
        $DefenderPlatformVersion = (($DefenderPlatformUpdate.Content).tostring() -split "[`r`n]" | Select-String 'New version:') -replace '[^0-9.]'

        Write-Host
        Write-Host "Latest Defender Platform version - $DefenderPlatformVersion" -ForegroundColor Magenta
        $DefenderPlatformVersion
    
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

$Date = Get-Date
$Description = "Updated Defender Antivirus Compliance Policy on $Date"
$DefenderPlatformVersion = Get-LatestDefenderPlatformUpdate

$Update = New-Object -TypeName psobject
$Update | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.windows10CompliancePolicy'
$Update | Add-Member -MemberType NoteProperty -Name 'description' -Value $Description

$DefenderCompliancePolicies = Get-DeviceCompliancePolicy | Where-Object { ($_.'@odata.type').contains('windows10CompliancePolicy') -and ($_.defenderEnabled) -ne '' }
foreach ($DefenderCompliancePolicy in $DefenderCompliancePolicies) {
    if ($DefenderCompliancePolicy.defenderVersion -lt $DefenderPlatformVersion) {
        Write-Host
        Write-Host "Updating Defender Antivirus Compliance Policy - $($DefenderCompliancePolicy.displayname)" -ForegroundColor Green
        
        $Update | Add-Member -MemberType NoteProperty -Name 'defenderVersion' -Value $DefenderPlatformVersion
                    
        # Creating JSON object to pass to Graph
        $JSON = $Update | ConvertTo-Json -Depth 3
        
        # Updating the compliance policy
        Update-DeviceCompliancePolicy -Id $DefenderCompliancePolicy.id -JSON $JSON
    }
    else {
        Write-Host "Defender Antivirus Compliance Policy - $($DefenderCompliancePolicy.displayname) is already up to date" -ForegroundColor Yellow
    }
  
}    