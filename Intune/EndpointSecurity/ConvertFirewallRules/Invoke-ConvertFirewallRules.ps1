[CmdletBinding()]
param(

    [Parameter(Mandatory = $true)]
    [String]$User,

    [Parameter(Mandatory = $true)]
    [String]$PolicyName,

    [Parameter(Mandatory = $true)]
    [String[]]$FirewallPolicies

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
    $tenant = $userUpn.Host

    Write-Host 'Checking for MSAL.PS module...'
    $MSALModule = Get-Module -Name 'MSAL.PS' -ListAvailable
    if ($null -eq $MSALModule) {
        Write-Host 'MSAL.PS Powershell module not installed...' -f Red
        Write-Host "Install by running 'Install-Module MSAL.PS' from an elevated PowerShell prompt and restart the script" -f Yellow
        Write-Host "Script can't continue..." -f Red
        break
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
            Write-Host 'Authorization Access Token is null, please re-run authentication...' -ForegroundColor Red
            break
        }
    }
    catch {
        Write-Host $_.Exception.Message -f Red
        Write-Host $_.Exception.ItemName -f Red
        break
    }
}
Function New-DeviceSettingsCatalog() {

    [cmdletbinding()]

    param
    (
        [parameter(Mandatory = $true)]
        $JSON
    )

    $graphApiVersion = 'Beta'
    $Resource = 'deviceManagement/configurationPolicies'

    try {
        Test-Json -Json $JSON
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
Function Get-DeviceEndpointSecProfile() {

    [cmdletbinding()]

    param (

        [Parameter(Mandatory = $false)]
        $Name,

        [Parameter(Mandatory = $false)]
        $Id

    )

    $graphApiVersion = 'Beta'
    $Resource = 'deviceManagement/intents'

    try {
        if ($Id) {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource/$Id"
            Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get
        }
        elseif ($Name) {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value | Where-Object { ($_.displayName).contains("$Name") }
        }
        Else {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-RestMethod -Method Get -Uri $uri -Headers $authToken).value
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
Function Get-DeviceEndpointSecCategorySetting() {

    <#
    .SYNOPSIS
    This function is used to get an Endpoint Security category setting from a specific policy using the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets a policy category setting
    .EXAMPLE
    Get-EndpointSecurityCategorySetting -PolicyId $policyId -categoryId $categoryId
    Gets an Endpoint Security Categories from a specific template in Endpoint Manager
    .NOTES
    NAME: Get-EndpointSecurityCategory
    #>

    [cmdletbinding()]

    param
    (
        [Parameter(Mandatory = $true)]

        $Id,
        [Parameter(Mandatory = $true)]

        $categoryId
    )

    $graphApiVersion = 'Beta'
    $Resource = "deviceManagement/intents/$Id/categories/$categoryId/settings?`$expand=Microsoft.Graph.DeviceManagementComplexSettingInstance/Value"

    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        (Invoke-RestMethod -Method Get -Uri $uri -Headers $authToken).value
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
Function Get-DeviceEndpointSecTemplateCategory() {

    <#
    .SYNOPSIS
    This function is used to get all Endpoint Security categories from a specific template using the Graph API REST interface
    .DESCRIPTION
    The function connects to the Graph API Interface and gets all template categories
    .EXAMPLE
    Get-EndpointSecurityTemplateCategory -TemplateId $templateId
    Gets an Endpoint Security Categories from a specific template in Endpoint Manager
    .NOTES
    NAME: Get-EndpointSecurityTemplateCategory
    #>

    [cmdletbinding()]

    param
    (
        [Parameter(Mandatory = $true)]

        $Id
    )

    $graphApiVersion = 'Beta'
    $Resource = "deviceManagement/templates/$Id/categories"

    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        (Invoke-RestMethod -Method Get -Uri $uri -Headers $authToken).value
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
Function Get-DeviceEndpointSecTemplate() {

    [cmdletbinding()]

    param (

        [Parameter(Mandatory = $false)]
        $Name,

        [Parameter(Mandatory = $false)]
        $Id

    )

    $graphApiVersion = 'Beta'
    $Resource = "deviceManagement/templates?`$filter=(isof(%27microsoft.graph.securityBaselineTemplate%27))"

    try {
        if ($Id) {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource/$Id"
            Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get
        }
        elseif ($Name) {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value | Where-Object { ($_.displayName).contains("$Name") }
        }
        Else {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-RestMethod -Method Get -Uri $uri -Headers $authToken).value
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
#endregion Functions

#region Authentication
# Checking if authToken exists before running authentication
if ($global:authToken) {
    # Setting DateTime to Universal time to work in all timezones
    $DateTime = (Get-Date).ToUniversalTime()
    # If the authToken exists checking when it expires
    $TokenExpires = ($authToken.ExpiresOn.datetime - $DateTime).Minutes
    if ($TokenExpires -le 0) {
        Write-Host 'Authentication Token expired' $TokenExpires 'minutes ago' -ForegroundColor Yellow
        # Defining User Principal Name if not present
        if ($null -eq $User -or $User -eq '') {
            $User = Read-Host -Prompt 'Please specify your user principal name for Azure Authentication'
        }
        $global:authToken = Get-AuthTokenMSAL -User $User
    }
}
else {
    if ($null -eq $User -or $User -eq '') {
        $User = Read-Host -Prompt 'Please specify your user principal name for Azure Authentication'
    }
    # Getting the authorization token
    $global:authToken = Get-AuthTokenMSAL -User $User$Filename
    Write-Host 'Connected to Graph API' -ForegroundColor Green
    Write-Host
}
#endregion

# Get the existing FW policy and settings

# Testing
#$PolicyName = 'COPE_FW_RulesMigrated'
#$FirewallPolicies = @('LegacyRules-0', 'LegacyRules-1', 'LegacyRules-2', 'LegacyRules-3')

# Variables for Template IDs and to capture Rules
$FWRules = @()
$FWTemplateID = '4356d05c-a4ab-4a07-9ece-739f7c792910'

foreach ($FirewallPolicy in $FirewallPolicies) {
    $EndpointSecProfile = Get-DeviceEndpointSecProfile -Name $FirewallPolicy
    if (($null -eq $EndpointSecProfile) -or ($EndpointSecProfile.templateId -ne $FWTemplateID)) {
        Write-Host "Unable to find Legacy Firewall Rule Profile named $FirewallPolicy or $FirewallPolicy Profile is not a Firewall Rule profile, script will end." -ForegroundColor Red
        Break
    }
    else {
        $EndpointSecTemplates = Get-DeviceEndpointSecTemplate
        $EndpointSecTemplate = $EndpointSecTemplates | Where-Object { $_.id -eq $EndpointSecProfile.templateId }
        $EndpointSecCategories = Get-DeviceEndpointSecTemplateCategory -Id $EndpointSecTemplate.id
        Write-Host "Found Legacy Firewall Rule Profile $FirewallPolicy" -ForegroundColor Green
        foreach ($EndpointSecCategory in $EndpointSecCategories) {
            $EndpointSecSettings = Get-DeviceEndpointSecCategorySetting -Id $EndpointSecProfile.id -categoryId $EndpointSecCategories.id
            # Existing FW rules
            $FWRules += $EndpointSecSettings.valueJson | ConvertFrom-Json
        }
    }
}

Write-Host "Captured $($FWRules.count) rules from the provided legacy Endpoint Security Firewall Rules profiles." -ForegroundColor Green

# Sorting rules into groups of 100 for Setting Catalog requirements
$counter = [pscustomobject] @{ Value = 0 }
$groupSize = 100
$FWRuleGroups = $FWRules | Group-Object -Property { [math]::Floor($counter.Value++ / $groupSize) }

# Looping through each group of rules
foreach ($FWRuleGroup in $FWRuleGroups) {

    # Sets the Name of the policies
    $NewPolicyName = $PolicyName + '-' + $FWRuleGroup.Name
    $PolicyDescription = 'Migrated Firewall Rules Policy'

    # New Settings Catalog policy start and end

    $JSONPolicyStart = @"
{
    "description": "$PolicyDescription",
    "name": "$NewPolicyName",
    "platforms": "windows10",
    "technologies@odata.type": "#microsoft.graph.deviceManagementConfigurationTechnologies",
    "technologies": "mdm,microsoftSense",
    "templateReference": {
            "@odata.type": "#microsoft.graph.deviceManagementConfigurationPolicyTemplateReference",
            "templateId": "19c8aa67-f286-4861-9aa0-f23541d31680_1",
            "templateFamily@odata.type": "#microsoft.graph.deviceManagementConfigurationTemplateFamily",
            "templateFamily": "endpointSecurityFirewall",
            "templateDisplayName": "Microsoft Defender Firewall Rules",
            "templateDisplayVersion": "Version 1"
        },
    "settings": [
        {
            "@odata.type": "#microsoft.graph.deviceManagementConfigurationSetting",
            "settingInstance": {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationGroupSettingCollectionInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}",
                "settingInstanceTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                    "settingInstanceTemplateId": "76c7a8be-67d2-44bf-81a5-38c94926b1a1"
                },
                "groupSettingCollectionValue@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationGroupSettingValue)",
                "groupSettingCollectionValue": [

"@

    $JSONPolicyEnd = @'
                ]
            }
        }
    ]
}
'@

    # Processing the rules
    $JSONAllRules = @()
    $Rules = $FWRuleGroup.Group
    $RuleNameCount = 0
    foreach ($Rule in $Rules) {

        # Capturing existing rules with duplicate names, as Settings Catalog will not allow duplicates
        $DuplicateNames = $Rules.displayName | Group-Object | Where-Object { $_.count -gt 1 }

        # Blank Out variables as not all rules have each variable
        Clear-Variable JSONRule*
        Clear-Variable -Name ('Name', 'Description', 'Direction', 'Action', 'FWProfiles', 'PackageFamilyName', 'FilePath', 'Service', 'Protocol', 'LocalPorts', 'RemotePorts', 'Interfaces', 'UseAnyLocalAddresses', 'LocalAddresses', 'UseAnyRemoteAddresses', 'RemoteAddresses') -ErrorAction Ignore

        # Capturing the Rule Data
        $Name = $Rule.displayName
        if ($DuplicateNames.name -contains $Name) {
            $Name = $Name + '-' + $RuleNameCount++
        }
        $Description = $Rule.description
        $Direction = $Rule.trafficDirection
        $Action = $Rule.action
        $FWProfiles = $Rule.profileTypes
        $PackageFamilyName = $Rule.packageFamilyName
        $FilePath = ($Rule.filePath).Replace('\', '\\')
        $Service = $Rule.serviceName
        $Protocol = $Rule.protocol
        $LocalPorts = $Rule.localPortRanges
        $RemotePorts = $Rule.remotePortRanges
        $Interfaces = $Rule.interfaceTypes
        $AuthUsers = $Rule.localUserAuthorizations
        $UseAnyLocalAddresses = $Rule.useAnyLocalAddressRange
        $LocalAddresses = $Rule.actualLocalAddressRanges
        $UseAnyRemoteAddresses = $Rule.useAnyRemoteAddressRange
        $RemoteAddresses = $Rule.actualRemoteAddressRanges

        # Setting the Start of each rule
        $JSONRuleStart = @'
        {
            "@odata.type": "#microsoft.graph.deviceManagementConfigurationGroupSettingValue",
            "settingValueTemplateReference": null,
            "children@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSettingInstance)",
            "children": [
'@

        # JSON data is different for first rule in the policy
        if ($Rule -eq $Rules[0]) {
            # Rule Name
            $JSONRuleName = @"
        {
            "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
            "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_name",
            "settingInstanceTemplateReference": {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                "settingInstanceTemplateId": "116a696a-3270-493e-9938-c336cf05ea98"
            },
            "simpleSettingValue": {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                "value": "$Name",
                "settingValueTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingValueTemplateReference",
                    "settingValueTemplateId": "12994a33-6185-4c3d-a0e8-69316f6293ea",
                    "useTemplateDefault": false
                }
            }
        },

"@

            # Rule State (Enabled)
            $JSONRuleState = @'
        {
            "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
            "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_enabled",
            "settingInstanceTemplateReference": {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                "settingInstanceTemplateId": "4e150e1a-6a10-49b2-a20c-911bf44ea767"
            },
            "choiceSettingValue": {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                "value": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_enabled_1",
                "settingValueTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingValueTemplateReference",
                    "settingValueTemplateId": "7562f243-f281-4f6f-b7e6-ecdb76dc1f1b",
                    "useTemplateDefault": false
                },
                "children@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSettingInstance)",
                "children": []
            }
        },

'@

            # Rule Direction
            $JSONRuleDirection = @"
        {
            "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
            "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_direction",
            "settingInstanceTemplateReference": {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                "settingInstanceTemplateId": "2114ad3d-157c-47d3-b646-60fcf50949c7"
            },
            "choiceSettingValue": {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                "value": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_direction_$Direction",
                "settingValueTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingValueTemplateReference",
                    "settingValueTemplateId": "8b45e13b-952d-4164-bbac-37f4e97b7985",
                    "useTemplateDefault": false
                },
                "children@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSettingInstance)",
                "children": []
            }
        },

"@

            # Edge Traversal
            <#$JSONRuleEdgeTraversal = @'
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_edgetraversal",
                "settingInstanceTemplateReference": {
                  "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                  "settingInstanceTemplateId": "fe674767-404d-4994-ac86-016f209851ee"
                },
                "choiceSettingValue": {
                  "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                  "value": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_edgetraversal_1",
                  "settingValueTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingValueTemplateReference",
                    "settingValueTemplateId": "682b3827-caec-4378-99b3-0400c2c0537b",
                    "useTemplateDefault": false
                  },
                  "children@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSettingInstance)",
                  "children": []
                }
            },
'@#>
            # Protocol
            if ($null -ne $Protocol) {
                $JSONRuleProtocol = @"
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_protocol",
                "settingInstanceTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                    "settingInstanceTemplateId": "b8f45398-674f-40c3-ab18-e002aa8e589b"
                    },
                "simpleSettingValue": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationIntegerSettingValue",
                    "value": "$Protocol",
                    "settingValueTemplateReference": {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingValueTemplateReference",
                        "settingValueTemplateId": "27d0d86c-d87d-473b-a41c-eef503d8baec",
                        "useTemplateDefault": false
                    }
                }
            },

"@
            }

            # Local Address Ranges
            if ($UseAnyLocalAddresses -eq $false) {
                $JSONRuleLocalAddressRangeStart = @'
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingCollectionInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_localaddressranges",
                "settingInstanceTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                    "settingInstanceTemplateId": "8b5de251-c683-4440-91d6-3b679b0aa5aa"
                },
                "simpleSettingCollectionValue@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSimpleSettingValue)",
                "simpleSettingCollectionValue": [

'@
                $JSONLocalAddresses = @()
                foreach ($LocalAddress in $LocalAddresses) {
                    # Last address in the set
                    if (($LocalAddress -eq $LocalAddresses[-1]) -or ($LocalAddresses.count -eq '1')) {
                        $JSONRuleLocalAddress = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$LocalAddress"
                    }

"@
                    }
                    else {
                        $JSONRuleLocalAddress = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$LocalAddress"
                    },

"@
                    }
                    $JSONLocalAddresses += $JSONRuleLocalAddress
                }
                $JSONRuleLocalAddressRangeEnd = @'

                ]
            },

'@
                $JSONRuleLocalAddressRange = $JSONRuleLocalAddressRangeStart + $JSONLocalAddresses + $JSONRuleLocalAddressRangeEnd
            }

            # Interface Type
            if ($Interfaces -ne 'notConfigured') {
                $JSONRuleInterface = @'
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingCollectionInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_interfacetypes",
                "settingInstanceTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                    "settingInstanceTemplateId": "406b5410-e52e-4df3-933f-1ee6e550a5c8"
                },
                "choiceSettingCollectionValue@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationChoiceSettingValue)",
                "choiceSettingCollectionValue": [
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_interfacetypes_all",
                        "children@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSettingInstance)",
                        "children": []
                    }
                ]
            },

'@
            }

            # Package Family Name
            If (!([string]::IsNullOrEmpty($PackageFamilyName))) {
                $JSONRulePackageFamily = @"
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_app_packagefamilyname",
                "settingInstanceTemplateReference": {
                  "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                  "settingInstanceTemplateId": "1a91448b-b04e-4cb0-a80c-10ec64addfda"
                },
                "simpleSettingValue": {
                  "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                  "value": "$PackageFamilyName",
                  "settingValueTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingValueTemplateReference",
                    "settingValueTemplateId": "a9b123c6-1c6f-4de3-8840-34f91dfb9422",
                    "useTemplateDefault": false
                  }
                }
            },

"@
            }

            # App File Path
            if (!([string]::IsNullOrEmpty($FilePath))) {
                $JSONRuleFilePath = @"
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_app_filepath",
                "settingInstanceTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                    "settingInstanceTemplateId": "dd825fa0-961b-4fcc-a6b3-4d2dc0419d4e"
                },
                "simpleSettingValue": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                    "value": "$FilePath",
                    "settingValueTemplateReference": {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingValueTemplateReference",
                        "settingValueTemplateId": "8c94fefa-67e5-40b5-8d97-6fca4f0c1e98",
                        "useTemplateDefault": false
                    }
                }
            },

"@
            }

            # Authorized Users
            if (!([string]::IsNullOrEmpty($AuthUsers))) {
                $JSONRuleAuthUsersStart = @'
                {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingCollectionInstance",
                    "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_localuserauthorizedlist",
                    "settingInstanceTemplateReference": {
                      "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                      "settingInstanceTemplateId": "b11c8e7d-babc-4899-a4b4-04683b898faa"
                    },
                    "simpleSettingCollectionValue@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSimpleSettingValue)",
                    "simpleSettingCollectionValue": [

'@
                $JSONAuthUsers = @()
                foreach ($AuthUser in $AuthUsers) {
                    # Last address in the set
                    if (($AuthUser -eq $AuthUsers[-1]) -or ($AuthUsers.count -eq '1')) {
                        $JSONRuleAuthUser = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$AuthUser"
                    }

"@
                    }
                    else {
                        $JSONRuleAuthUser = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$AuthUser"
                    },

"@
                    }
                    $JSONAuthUsers += $JSONRuleAuthUser
                }
                $JSONRuleAuthUsersEnd = @'

                ]
            },
'@
                $JSONRuleAuthUsers = $JSONRuleAuthUsersStart + $JSONAuthUsers + $JSONRuleAuthUsersEnd
            }
            # Remote Ports
            if (!([string]::IsNullOrEmpty($RemotePorts))) {
                $JSONRuleRemotePortsStart = @'
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingCollectionInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_remoteportranges",
                "settingInstanceTemplateReference": {
                  "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                  "settingInstanceTemplateId": "de5d058e-ab1d-4772-81f5-32b6a35b4587"
                },
                "simpleSettingCollectionValue@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSimpleSettingValue)",
                "simpleSettingCollectionValue": [

'@
                $JSONRemotePorts = @()
                foreach ($RemotePort in $RemotePorts) {
                    # Last address in the set
                    if (($RemotePort -eq $RemotePorts[-1]) -or ($RemotePorts.count -eq '1')) {
                        $JSONRuleRemotePort = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$RemotePort"
                    }

"@
                    }
                    else {
                        $JSONRuleRemotePort = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$RemotePort"
                    },

"@
                    }
                    $JSONRemotePorts += $JSONRuleRemotePort
                }
                $JSONRuleRemotePortsEnd = @'

                ]
            },

'@
                $JSONRuleRemotePorts = $JSONRuleRemotePortsStart + $JSONRemotePorts + $JSONRuleRemotePortsEnd
            }

            # Firewall Profile
            if ($FWProfiles -ne 'notConfigured') {
                $JSONRuleFWProfileStart = @'
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingCollectionInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_profiles",
                "settingInstanceTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                    "settingInstanceTemplateId": "7dc9b243-cdd2-4359-b5f5-0c48edb8fd34"
                },
                "choiceSettingCollectionValue@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationChoiceSettingValue)",
                "choiceSettingCollectionValue": [

'@

                $JSONRuleFWProfileTypes = @()
                foreach ($FWProfile in $FWProfiles) {
                    Switch ($FWProfile) {
                        'domain' { $FWProfileNo = '1' }
                        'private' { $FWProfileNo = '2' }
                        'public' { $FWProfileNo = '4' }
                    }

                    if (($FWProfile -eq $FWProfiles[-1]) -or ($FWProfiles.count -eq '1')) {
                        $JSONRuleFWProfileType = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_profiles_$FWProfileNo",
                        "children@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSettingInstance)",
                        "children": []
                    }

"@
                    }
                    else {
                        $JSONRuleFWProfileType = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_profiles_$FWProfileNo",
                        "children@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSettingInstance)",
                        "children": []
                    },

"@
                    }

                    $JSONRuleFWProfileTypes += $JSONRuleFWProfileType
                }

                $JSONRuleFWProfileEnd = @'
                ]
            },

'@

                $JSONRuleFWProfile = $JSONRuleFWProfileStart + $JSONRuleFWProfileTypes + $JSONRuleFWProfileEnd
            }

            # Service Name
            if (!([string]::IsNullOrEmpty($Service))) {
                $JSONRuleService = @"
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_app_servicename",
                "settingInstanceTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                    "settingInstanceTemplateId": "1bd709fe-1cd4-4cc4-9a6f-4cb7f104da66"
                },
                "simpleSettingValue": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                    "value": "$Service",
                    "settingValueTemplateReference": {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingValueTemplateReference",
                        "settingValueTemplateId": "c77294ec-795e-43dc-9af6-775b3b2f911d",
                        "useTemplateDefault": false
                    }
                }
            },

"@
            }

            # Local Ports
            if ((!([string]::IsNullOrEmpty($LocalPorts)))) {
                $JSONRuleLocalPortsStart = @'
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingCollectionInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_localportranges",
                "settingInstanceTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                    "settingInstanceTemplateId": "b57dc83e-5bf3-439a-b923-4c3e49ac9e2d"
                },
                "simpleSettingCollectionValue@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSimpleSettingValue)",
                "simpleSettingCollectionValue": [

'@
                $JSONLocalPorts = @()
                foreach ($LocalPort in $LocalPorts) {
                    # Last address in the set
                    if (($LocalPort -eq $LocalPorts[-1]) -or ($LocalPorts.count -eq '1')) {
                        $JSONRuleLocalPort = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$LocalPort"
                    }

"@
                    }
                    else {
                        $JSONRuleLocalPort = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$LocalPort"
                    },

"@
                    }
                    $JSONLocalPorts += $JSONRuleLocalPort
                }
                $JSONRuleLocalPortsEnd = @'

                ]
            },

'@
                $JSONRuleLocalPorts = $JSONRuleLocalPortsStart + $JSONLocalPorts + $JSONRuleLocalPortsEnd
            }

            # Remote Address Ranges
            if ($UseAnyRemoteAddresses -eq $false) {
                $JSONRuleRemoteAddressRangeStart = @'
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingCollectionInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_remoteaddressranges",
                "settingInstanceTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                    "settingInstanceTemplateId": "bf9855fc-f2c0-4241-94cf-94cf823f1c1c"
                },
                "simpleSettingCollectionValue@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSimpleSettingValue)",
                "simpleSettingCollectionValue": [

'@
                $JSONRemoteAddresses = @()
                foreach ($RemoteAddress in $RemoteAddresses) {
                    # Last address in the set
                    if (($RemoteAddress -eq $RemoteAddresses[-1]) -or ($RemoteAddresses.count -eq '1')) {
                        $JSONRuleRemoteAddress = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$RemoteAddress"
                    }

"@
                    }
                    else {
                        $JSONRuleRemoteAddress = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$RemoteAddress"
                    },

"@
                    }
                    $JSONRemoteAddresses += $JSONRuleRemoteAddress
                }
                $JSONRuleRemoteAddressRangeEnd = @'

                ]
            },

'@
                $JSONRuleRemoteAddressRange = $JSONRuleRemoteAddressRangeStart + $JSONRemoteAddresses + $JSONRuleRemoteAddressRangeEnd
            }

            # Rule Action
            Switch ($Action) {
                'allowed' { $ActionType = '1' }
                'blocked' { $ActionType = '0' }
            }
            $JSONRuleAction = @"
        {
            "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
            "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_action_type",
            "settingInstanceTemplateReference": {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                "settingInstanceTemplateId": "0565cfd1-21c2-4965-b87f-6bde2b8d2cbd"
            },
            "choiceSettingValue": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                    "value": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_action_type_$ActionType",
                    "settingValueTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingValueTemplateReference",
                    "settingValueTemplateId": "419773d8-bffe-4d6f-a91f-286871963f5c",
                    "useTemplateDefault": false
            },
            "children@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSettingInstance)",
            "children": []
            }
        },

"@

            # Rule Description
            $JSONRuleDescription = @"
        {
            "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
            "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_description",
            "settingInstanceTemplateReference": {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingInstanceTemplateReference",
                "settingInstanceTemplateId": "6c85987f-3adb-4f8d-93e1-4f23e238121b"
            },
            "simpleSettingValue": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                    "value": "$Description",
                    "settingValueTemplateReference": {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSettingValueTemplateReference",
                    "settingValueTemplateId": "18ab9c3a-b6be-4995-9438-289c34eee294",
                    "useTemplateDefault": false
                }
            }
        }

"@

            #Rule ending
            if ($Rule -eq $Rules[-1]) {
                $JSONRuleEnd = @'
                ]
            }

'@
            }
            else {
                $JSONRuleEnd = @'
                ]
            },

'@
            }

            # Build the first Rule and add it to array
            $JSONRule = $JSONRuleStart + $JSONRuleName + $JSONRuleState + $JSONRuleDirection + $JSONRuleProtocol + $JSONRuleLocalAddressRange + $JSONRuleInterface + $JSONRulePackageFamily + $JSONRuleFilePath + $JSONRuleAuthUsers + $JSONRuleRemotePorts + $JSONRuleFWProfile + $JSONRuleService + $JSONRuleLocalPorts + $JSONRuleRemoteAddressRange + $JSONRuleAction + $JSONRuleDescription + $JSONRuleEnd
            $JSONAllRules += $JSONRule
        }
        # JSON data is different for each subsequent rule in the policy
        else {
            # Rule Name
            $JSONRuleName = @"
        {
            "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
            "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_name",
            "settingInstanceTemplateReference": null,
            "simpleSettingValue": {
              "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
              "settingValueTemplateReference": null,
              "value": "$Name"
            }
        },

"@

            # Rule State (Enabled)
            $JSONRuleState = @'
        {
            "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
            "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_enabled",
            "settingInstanceTemplateReference": null,
            "choiceSettingValue": {
              "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
              "settingValueTemplateReference": null,
              "value": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_enabled_1",
              "children@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSettingInstance)",
              "children": []
            }
        },

'@

            # Rule Direction
            $JSONRuleDirection = @"
        {
            "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
            "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_direction",
            "settingInstanceTemplateReference": null,
            "choiceSettingValue": {
              "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
              "settingValueTemplateReference": null,
              "value": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_direction_$Direction",
              "children@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSettingInstance)",
              "children": []
            }
        },

"@

            # Edge Traversal
            <#$JSONRuleEdgeTraversal = @'
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_edgetraversal",
                "settingInstanceTemplateReference": null,
                "choiceSettingValue": {
                  "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                  "settingValueTemplateReference": null,
                  "value": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_edgetraversal_1",
                  "children@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSettingInstance)",
                  "children": []
                }
            },
'@#>
            # Protocol
            if ($null -ne $Protocol) {
                $JSONRuleProtocol = @"
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_protocol",
                "settingInstanceTemplateReference": null,
                "simpleSettingValue": {
                  "@odata.type": "#microsoft.graph.deviceManagementConfigurationIntegerSettingValue",
                  "settingValueTemplateReference": null,
                  "value": "$Protocol"
                }
            },

"@
            }

            # Local Address Ranges
            if ($UseAnyLocalAddresses -eq $false) {
                $JSONRuleLocalAddressRangeStart = @'
            "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingCollectionInstance",
            "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_localaddressranges",
            "settingInstanceTemplateReference": null,
            "simpleSettingCollectionValue@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSimpleSettingValue)",
            "simpleSettingCollectionValue": [

'@
                $JSONLocalAddresses = @()
                foreach ($LocalAddress in $LocalAddresses) {
                    # Last address in the set
                    if (($LocalAddress -eq $LocalAddresses[-1]) -or ($LocalAddresses.count -eq '1')) {
                        $JSONRuleLocalAddress = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$LocalAddress"
                    }

"@
                    }
                    else {
                        $JSONRuleLocalAddress = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$LocalAddress"
                    },

"@
                    }
                    $JSONLocalAddresses += $JSONRuleLocalAddress
                }
                $JSONRuleLocalAddressRangeEnd = @'

                ]
            },
'@
                $JSONRuleLocalAddressRange = $JSONRuleLocalAddressRangeStart + $JSONLocalAddresses + $JSONRuleLocalAddressRangeEnd
            }

            # Interface Type
            if ($Interfaces -ne 'notConfigured') {
                $JSONRuleInterface = @'
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingCollectionInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_interfacetypes",
                "settingInstanceTemplateReference": null,
                "choiceSettingCollectionValue@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationChoiceSettingValue)",
                "choiceSettingCollectionValue": [
                  {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                    "settingValueTemplateReference": null,
                    "value": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_interfacetypes_all",
                    "children@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSettingInstance)",
                    "children": []
                  }
                ]
            },

'@
            }

            # Package Family Name
            If (!([string]::IsNullOrEmpty($PackageFamilyName))) {
                $JSONRulePackageFamily = @"
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_app_packagefamilyname",
                "settingInstanceTemplateReference": null,
                "simpleSettingValue": {
                  "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                  "settingValueTemplateReference": null,
                  "value": "$PackageFamilyName"
                }
            },

"@
            }

            # App File Path
            if (!([string]::IsNullOrEmpty($FilePath))) {
                $JSONRuleFilePath = @"
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_app_filepath",
                "settingInstanceTemplateReference": null,
                "simpleSettingValue": {
                  "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                  "settingValueTemplateReference": null,
                  "value": "$FilePath"
                }
            },

"@
            }

            # Authorized Users
            if (!([string]::IsNullOrEmpty($AuthUsers))) {
                $JSONRuleAuthUsersStart = @'
                {
                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingCollectionInstance",
                    "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_localuserauthorizedlist",
                    "settingInstanceTemplateReference": null,
                    "simpleSettingCollectionValue@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSimpleSettingValue)",
                    "simpleSettingCollectionValue": [

'@
                $JSONAuthUsers = @()
                foreach ($AuthUser in $AuthUsers) {
                    # Last address in the set
                    if (($AuthUser -eq $AuthUsers[-1]) -or ($AuthUsers.count -eq '1')) {
                        $JSONRuleAuthUser = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$AuthUser"
                    }

"@
                    }
                    else {
                        $JSONRuleAuthUser = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$AuthUser"
                    },

"@
                    }
                    $JSONAuthUsers += $JSONRuleAuthUser
                }
                $JSONRuleAuthUsersEnd = @'

                ]
            },
'@
                $JSONRuleAuthUsers = $JSONRuleAuthUsersStart + $JSONAuthUsers + $JSONRuleAuthUsersEnd
            }

            # Remote Ports
            if (!([string]::IsNullOrEmpty($RemotePorts))) {
                $JSONRuleRemotePortsStart = @'
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingCollectionInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_remoteportranges",
                "settingInstanceTemplateReference": null,
                "simpleSettingCollectionValue@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSimpleSettingValue)",
                "simpleSettingCollectionValue": [

'@
                $JSONRemotePorts = @()
                foreach ($RemotePort in $RemotePorts) {
                    # Last address in the set
                    if (($RemotePort -eq $RemotePorts[-1]) -or ($RemotePorts.count -eq '1')) {
                        $JSONRuleRemotePort = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$RemotePort"
                    }

"@
                    }
                    else {
                        $JSONRuleRemotePort = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$RemotePort"
                    },

"@
                    }
                    $JSONRemotePorts += $JSONRuleRemotePort
                }
                $JSONRuleRemotePortsEnd = @'

                ]
            },
'@
                $JSONRuleRemotePorts = $JSONRuleRemotePortsStart + $JSONRemotePorts + $JSONRuleRemotePortsEnd
            }


            # Firewall Profile
            if ($FWProfiles -ne 'notConfigured') {
                $JSONRuleFWProfileStart = @'
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingCollectionInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_profiles",
                "settingInstanceTemplateReference": null,
                "choiceSettingCollectionValue@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationChoiceSettingValue)",
                "choiceSettingCollectionValue": [

'@

                $JSONRuleFWProfileTypes = @()
                foreach ($FWProfile in $FWProfiles) {
                    Switch ($FWProfile) {
                        'domain' { $FWProfileNo = '1' }
                        'private' { $FWProfileNo = '2' }
                        'public' { $FWProfileNo = '4' }
                    }

                    if (($FWProfile -eq $FWProfiles[-1]) -or ($FWProfiles.count -eq '1')) {
                        $JSONRuleFWProfileType = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_profiles_$FWProfileNo",
                        "children@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSettingInstance)",
                        "children": []
                    }

"@
                    }
                    else {
                        $JSONRuleFWProfileType = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_profiles_$FWProfileNo",
                        "children@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSettingInstance)",
                        "children": []
                    },

"@
                    }

                    $JSONRuleFWProfileTypes += $JSONRuleFWProfileType
                }

                $JSONRuleFWProfileEnd = @'
                ]
            },

'@

                $JSONRuleFWProfile = $JSONRuleFWProfileStart + $JSONRuleFWProfileTypes + $JSONRuleFWProfileEnd
            }

            # Service Name
            if (!([string]::IsNullOrEmpty($Service))) {
                $JSONRuleService = @"
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_app_servicename",
                "settingInstanceTemplateReference": null,
                "simpleSettingValue": {
                  "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                  "settingValueTemplateReference": null,
                  "value": "$Service"
                }
            },

"@
            }

            # Local Ports
            if ((!([string]::IsNullOrEmpty($LocalPorts)))) {
                $JSONRuleLocalPortsStart = @'
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingCollectionInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_localportranges",
                "settingInstanceTemplateReference": null,
                "simpleSettingCollectionValue@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSimpleSettingValue)",
                "simpleSettingCollectionValue": [

'@
                $JSONLocalPorts = @()
                foreach ($LocalPort in $LocalPorts) {
                    # Last address in the set
                    if (($LocalPort -eq $LocalPorts[-1]) -or ($LocalPorts.count -eq '1')) {
                        $JSONRuleLocalPort = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$LocalPort"
                    }

"@
                    }
                    else {
                        $JSONRuleLocalPort = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$LocalPort"
                    },

"@
                    }
                    $JSONLocalPorts += $JSONRuleLocalPort
                }
                $JSONRuleLocalPortsEnd = @'
                ]
            },

'@
                $JSONRuleLocalPorts = $JSONRuleLocalPortsStart + $JSONLocalPorts + $JSONRuleLocalPortsEnd
            }

            # Remote Address Ranges
            if ($UseAnyRemoteAddresses -eq $false) {
                $JSONRuleRemoteAddressRangeStart = @'
            {
                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingCollectionInstance",
                "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_remoteaddressranges",
                "settingInstanceTemplateReference": null,
                "simpleSettingCollectionValue@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSimpleSettingValue)",
                "simpleSettingCollectionValue": [

'@
                $JSONRemoteAddresses = @()
                foreach ($RemoteAddress in $RemoteAddresses) {
                    # Last address in the set
                    if (($RemoteAddress -eq $RemoteAddresses[-1]) -or ($RemoteAddresses.count -eq '1')) {
                        $JSONRuleRemoteAddress = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$RemoteAddress"
                    }

"@
                    }
                    else {
                        $JSONRuleRemoteAddress = @"
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$RemoteAddress"
                    },

"@
                    }
                    $JSONRemoteAddresses += $JSONRuleRemoteAddress
                }
                $JSONRuleRemoteAddressRangeEnd = @'
                ]
            },

'@
                $JSONRuleRemoteAddressRange = $JSONRuleRemoteAddressRangeStart + $JSONRemoteAddresses + $JSONRuleRemoteAddressRangeEnd
            }

            # Rule Action
            Switch ($Action) {
                'allowed' { $ActionType = '1' }
                'blocked' { $ActionType = '0' }
            }
            $JSONRuleAction = @"
        {
            "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
            "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_action_type",
            "settingInstanceTemplateReference": null,
            "choiceSettingValue": {
              "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
              "settingValueTemplateReference": null,
              "value": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_action_type_$ActionType",
              "children@odata.type": "#Collection(microsoft.graph.deviceManagementConfigurationSettingInstance)",
              "children": []
            }
        },

"@

            # Rule Description
            $JSONRuleDescription = @"
        {
            "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
            "settingDefinitionId": "vendor_msft_firewall_mdmstore_firewallrules_{firewallrulename}_description",
            "settingInstanceTemplateReference": null,
            "simpleSettingValue": {
              "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
              "settingValueTemplateReference": null,
              "value": "$Description"
            }
        }

"@

            #Rule ending
            if ($Rule -eq $Rules[-1]) {
                $JSONRuleEnd = @'
                ]
            }

'@
            }
            else {
                $JSONRuleEnd = @'
                ]
            },

'@
            }

            # Build the subequent Rule and add to array
            $JSONRule = $JSONRuleStart + $JSONRuleName + $JSONRuleState + $JSONRuleDirection + $JSONRuleProtocol + $JSONRuleLocalAddressRange + $JSONRuleInterface + $JSONRulePackageFamily + $JSONRuleFilePath + $JSONRuleAuthUsers + $JSONRuleRemotePorts + $JSONRuleFWProfile + $JSONRuleService + $JSONRuleLocalPorts + $JSONRuleRemoteAddressRange + $JSONRuleAction + $JSONRuleDescription + $JSONRuleEnd
            $JSONAllRules += $JSONRule
        }
    }

    # Combining the all the JSON to form the Settings Catalog policy
    $JSONPolicy = $JSONPolicyStart + $JSONAllRules + $JSONPolicyEnd
    Write-Host "Creating new Settings Catalog Policy $NewPolicyName" -ForegroundColor Cyan
    Try {
        New-DeviceSettingsCatalog -JSON $JSONPolicy
        Write-Host "Successfully created new Settings Catalog Policy $NewPolicyName" -ForegroundColor Green
    }
    Catch {
        Write-Host "Unable to create new Settings Catalog Policy $NewPolicyName, script will end." -ForegroundColor Red
        Break
    }

}