[CmdletBinding()]

param(

    [Parameter(Mandatory = $true)]
    [String]$xmlPath,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Enforce', 'Audit')]
    [string]$enforce,

    [Parameter(Mandatory = $true)]
    [boolean]$upload,

    [Parameter(Mandatory = $false)]
    [string]$displayName,

    [Parameter(Mandatory = $false)]
    [string]$policyName = 'Baseline',

    [Parameter(Mandatory = $false)]
    [String]$tenantId

)

#region variables
$upload = $true
$enforce = 'Audit'
$displayName = 'WIN_DEV_COPE_AppLocker_Upload'
$xmlPath = 'C:\Source\github\AaronLocker\AaronLocker\Outputs\AppLockerRules-20241014-1101-Audit.xml'
$encoding = 'UTF-8'
[String[]]$scopes = 'DeviceManagementConfiguration.ReadWrite.All'

#endregion variables

#region functions
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
Function Connect-ToGraph {
    <#
.SYNOPSIS
Authenticates to the Graph API via the Microsoft.Graph.Authentication module.

.DESCRIPTION
The Connect-ToGraph cmdlet is a wrapper cmdlet that helps authenticate to the Intune Graph API using the Microsoft.Graph.Authentication module. It leverages an Azure AD app ID and app secret for authentication or user-based auth.

.PARAMETER Tenant
Specifies the tenant (e.g. contoso.onmicrosoft.com) to which to authenticate.

.PARAMETER AppId
Specifies the Azure AD app ID (GUID) for the application that will be used to authenticate.

.PARAMETER AppSecret
Specifies the Azure AD app secret corresponding to the app ID that will be used to authenticate.

.PARAMETER Scopes
Specifies the user scopes for interactive authentication.

.EXAMPLE
Connect-ToGraph -tenantId $tenantId -appId $app -appSecret $secret

-#>
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $false)] [string]$tenantId,
        [Parameter(Mandatory = $false)] [string]$appId,
        [Parameter(Mandatory = $false)] [string]$appSecret,
        [Parameter(Mandatory = $false)] [string[]]$scopes
    )

    Process {
        Import-Module Microsoft.Graph.Authentication
        $version = (Get-Module microsoft.graph.authentication | Select-Object -ExpandProperty Version).major

        if ($AppId -ne '') {
            $body = @{
                grant_type    = 'client_credentials';
                client_id     = $appId;
                client_secret = $appSecret;
                scope         = 'https://graph.microsoft.com/.default';
            }

            $response = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -Body $body
            $accessToken = $response.access_token

            if ($version -eq 2) {
                Write-Host 'Version 2 module detected'
                $accesstokenfinal = ConvertTo-SecureString -String $accessToken -AsPlainText -Force
            }
            else {
                Write-Host 'Version 1 Module Detected'
                Select-MgProfile -Name Beta
                $accesstokenfinal = $accessToken
            }
            $graph = Connect-MgGraph -AccessToken $accesstokenfinal
            Write-Host "Connected to Intune tenant $TenantId using app-based authentication (Azure AD authentication not supported)"
        }
        else {
            if ($version -eq 2) {
                Write-Host 'Version 2 module detected'
            }
            else {
                Write-Host 'Version 1 Module Detected'
                Select-MgProfile -Name Beta
            }
            $graph = Connect-MgGraph -Scopes $scopes -TenantId $tenantId
            Write-Host "Connected to Intune tenant $($graph.TenantId)"
        }
    }
}
Function New-CustomProfile() {

    [cmdletbinding()]

    param
    (
        [parameter(Mandatory = $true)]
        $JSON
    )

    $graphApiVersion = 'Beta'
    $Resource = 'deviceManagement/deviceConfigurations'

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
#endregion functions

#region authentication
if ($upload -eq $true) {
    if (!$tenantId) {
        $tenantId = Read-Host 'Please enter in the Entra ID Tenant ID'

    }
    Import-Module Microsoft.Graph.Authentication
    if (Get-MgContext) {
        Write-Host 'Disconnecting from existing Graph session.' -ForegroundColor Cyan
        Disconnect-MgGraph
    }
    Write-Host 'Connecting to Graph' -ForegroundColor Cyan
    Connect-ToGraph -tenantId $tenantId -Scopes $scopes
    $existingScopes = (Get-MgContext).Scopes
    Write-Host 'Disconnecting from Graph to allow for changes to consent requirements' -ForegroundColor Cyan
    Disconnect-MgGraph
    Write-Host 'Connecting to Graph' -ForegroundColor Cyan
    Connect-ToGraph -tenantId $tenantId -Scopes $existingScopes
}
#endregion authentication

while (!(Test-Path -Path $xmlPath -PathType Leaf)) {
    $xmlPath = Read-Host 'Please enter the path to the AppLocker XML file'
}

Try {
    $dateTime = Get-Date -Format yyyyMMdd-HHmm
    $objectAppLocker = New-Object -TypeName psobject
    $omaSettings = @()
    $xmlFile = Get-ChildItem $xmlPath
    [xml]$xmlDoc = Get-Content $xmlFile
    # Convert to UTF-8 for Intune
    if ($xmlDoc.xml -like '*encoding="utf-16"') {
        $xmlDoc.xml = $($xmlDoc.CreateXmlDeclaration('1.0', $encoding, '')).Value
        $xmlDoc.Save($xmlFile.FullName)
    }

    $xmlFile = Get-ChildItem $xmlPath

    [xml]$xmlDoc = Get-Content $xmlFile
    $ruleCollections = $xmlDoc.ChildNodes.RuleCollection
    foreach ($ruleCollection in $ruleCollections) {
        $objectAppLockerSettings = New-Object -TypeName psobject
        # Sets enforcement mode
        if ($null -ne $ruleCollection.EnforcementMode) {
            if ($enforceMode -eq 'enforce') {
                $ruleCollection.EnforcementMode = 'Enforce'
            }
            else {
                $ruleCollection.EnforcementMode = 'AuditOnly'
            }
            #create separate files for Intune
            [xml]$xmlIntuneSetting = $ruleCollection.OuterXml
            if ($null -ne $($ruleCollection.Type)) {

                $appLockerType = switch ($($ruleCollection.Type)) {
                    'Appx' { 'StoreApps' }
                    'Dll' { 'DLL' }
                    'Exe' { 'EXE' }
                    'Msi' { 'MSI' }
                    'Script' { 'Script' }
                }

                $xmlDocIntuneSetting = "$($xmlFile.Directory.FullName)\$appLockerType-$($xmlFile.BaseName).xml"
                $xmlIntuneSetting.Save($xmlDocIntuneSetting)
                Write-Host "AppLocker settings for $appLockerType have been written to $xmlDocIntuneSetting" -ForegroundColor Green

                if ($upload -eq $true) {
                    [xml]$xmlDocIntunePartial = Get-Content $xmlDocIntuneSetting
                    [string]$omaUriValue = $xmlDocIntunePartial.RuleCollection.OuterXml
                    $omaUri = "./Vendor/MSFT/AppLocker/ApplicationLaunchRestrictions/$policyName/$appLockerType/Policy"
                    $objectAppLockerSettings | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value 'microsoft.graph.omaSettingString'
                    $objectAppLockerSettings | Add-Member -MemberType NoteProperty -Name 'displayName' -Value $appLockerType
                    $objectAppLockerSettings | Add-Member -MemberType NoteProperty -Name 'description' -Value $enforce
                    $objectAppLockerSettings | Add-Member -MemberType NoteProperty -Name 'omaUri' -Value $omaUri
                    $objectAppLockerSettings | Add-Member -MemberType NoteProperty -Name 'value' -Value $omaUrivalue
                    $omaSettings += $objectAppLockerSettings
                }

            }
            else {
                Write-Host 'help' -ForegroundColor Red
            }
        }
    }
    if ($upload -eq $true) {
        while (!$displayName) {
            $displayName = Read-Host 'Please enter a name for the AppLocker profile in Intune'
        }
        $name = $displayName + '-' + $dateTime
        $objectAppLocker | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.windows10CustomConfiguration'
        $objectAppLocker | Add-Member -MemberType NoteProperty -Name 'displayName' -Value $name
        $objectAppLocker | Add-Member -MemberType NoteProperty -Name 'description' -Value $name
        $objectAppLocker | Add-Member -MemberType NoteProperty -Name 'omaSettings' -Value @($omaSettings)

        $appLockerJSON = $objectAppLocker | ConvertTo-Json -Depth 5
        New-CustomProfile -JSON $appLockerJSON
    }
}
Catch {
    Write-Host 'help' -ForegroundColor Red
}

