[CmdletBinding()]
param(

    [Parameter(Mandatory = $true)]
    [String]$User,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Report', 'Import', 'ImportAssign')]
    [string]$Deployment

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
        Write-Host "Install by running 'Install-Module MSAL.PS -Scope CurrentUser' from an elevated PowerShell prompt" -f Yellow
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
Function Get-DeviceEPMReport() {

    [cmdletbinding()]

    param (

        [Parameter(Mandatory = $false)]
        [ValidateSet('Managed', 'Unmanaged')]
        [String]$Elevation,

        [Parameter(Mandatory = $false)]
        $Top

    )

    $graphApiVersion = 'beta'
    $Resource = 'deviceManagement/privilegeManagementElevations'

    try {
        if ($Elevation -eq 'Managed') {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?filter=(elevationType ne 'unmanagedElevation')"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).value
        }
        elseif ($Elevation -eq 'Unmanaged') {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?filter=(elevationType eq 'unmanagedElevation')"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).value
        }
        else {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).value
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
Function Get-IntuneGroup() {

    [cmdletbinding()]

    param
    (
        [parameter(Mandatory = $true)]
        [string]$Name
    )

    $graphApiVersion = 'beta'
    $Resource = 'groups'

    try {
        $authToken['ConsistencyLevel'] = 'eventual'
        $searchterm = 'search="displayName:' + $Name + '"'
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource`?$searchterm"
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
Function Get-DeviceSettingsCatalog() {

    [cmdletbinding()]

    param (

        [Parameter(Mandatory = $false)]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [string]$Id,

        [Parameter(Mandatory = $false)]
        [switch]$EPM

    )

    $graphApiVersion = 'beta'
    $Resource = "deviceManagement/configurationPolicies?`$filter=technologies has 'mdm'"

    try {
        if ($EPM) {
            $Resource = "deviceManagement/configurationPolicies?`$filter=templateReference/TemplateFamily eq 'endpointSecurityEndpointPrivilegeManagement'"
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
        }
        if ($Id) {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource/$Id"
            Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get
        }
        elseif ($Name) {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value | Where-Object { ($_.Name).contains("$Name") }
        }
        Else {
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
Function Add-DeviceSettingsCatalogAssignment() {

    [cmdletbinding()]

    param
    (
        [parameter(Mandatory = $true)]
        [string]$Id,

        [parameter(Mandatory = $false)]
        [string]$Name,

        [parameter(Mandatory = $true)]
        [string]$TargetGroupId,

        [parameter(Mandatory = $true)]
        [ValidateSet('Include', 'Exclude')]
        [string]$AssignmentType
    )

    $graphApiVersion = 'Beta'
    $Resource = "deviceManagement/configurationPolicies/$Id/assign"

    try {
        $TargetGroup = New-Object -TypeName psobject

        if ($AssignmentType -eq 'Exclude') {
            $TargetGroup | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.exclusionGroupAssignmentTarget'
        }
        elseif ($AssignmentType -eq 'Include') {
            $TargetGroup | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.groupAssignmentTarget'
        }

        $TargetGroup | Add-Member -MemberType NoteProperty -Name 'groupId' -Value "$TargetGroupId"

        $Target = New-Object -TypeName psobject
        $Target | Add-Member -MemberType NoteProperty -Name 'target' -Value $TargetGroup
        $TargetGroups = $Target

        # Creating JSON object to pass to Graph
        $Output = New-Object -TypeName psobject
        $Output | Add-Member -MemberType NoteProperty -Name 'assignments' -Value @($TargetGroups)
        $JSON = $Output | ConvertTo-Json -Depth 3

        # POST to Graph Service
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        Invoke-RestMethod -Uri $uri -Headers $authToken -Method Post -Body $JSON -ContentType 'application/json'
        Write-Host "Successfully assigned policy $Name" -ForegroundColor Green
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

$Date = (Get-Date -Format 'yyyy_MM_dd').ToString()

# Report
if ($Deployment -eq 'Report') {
    $ReportPath = Read-Host -Prompt 'Please specify a path to export the EPM data to e.g., C:\Temp'
    if (!(Test-Path "$ReportPath")) {
        New-Item -ItemType Directory -Path "$ReportPath" | Out-Null
    }
    $CSV = "$ReportPath\EPM_Report_$Date.csv"
    $Report = @()
    $Hashes = Get-DeviceEPMReport | Group-Object -Property hash
    foreach ($Hash in $Hashes) {

        $Elevations = $Hash.Group
        $Users = @()
        $Devices = @()

        foreach ($Elevation in $Elevations) {
            $FileName = $Elevation.filePath | Split-Path -Leaf
            $FileInternalName = $Elevation.internalName
            $FileCompany = $Elevation.companyName
            $FileProduct = $Elevation.productName
            $FileDescription = $Elevation.fileDescription
            $FilePath = ($Elevation.filePath | Split-Path) -replace '\\', '\\'
            $FileVersion = $Elevation.fileVersion
            $Users += $Elevation.upn
            $Devices += $Elevation.deviceName
        }

        $Data = [PSCustomObject]@{
            ElevationCount   = $Hash.Count
            Product          = $FileProduct
            Description      = $FileDescription
            Publisher        = $FileCompany
            FileName         = $FileName
            FileInternalName = $FileInternalName
            FileVersion      = $FileVersion
            FilePath         = $FilePath
            FileHash         = $Hash.Name
            Users            = (($Users | Get-Unique) -join ' ' | Out-String).Trim()
            Devices          = (($Devices | Get-Unique) -join ' ' | Out-String).Trim()
            ElevationType    = 'Automatic/UserAuthentication/UserJustification'
            Group            = 'GroupName'
        }

        $Report += $Data
    }

    # CSV Report
    $Report | Export-Csv -Path $CSV -NoTypeInformation
    Write-Output "Report exported to $CSV"
}
# Rule Impprt
elseif ($Deployment -like '*Import*') {
    $ImportPath = Read-Host -Prompt 'Please specify a path to EPM data CSV to e.g., C:\Temp\EPM_Data.csv'
    if (!(Test-Path "$ImportPath")) {
        Write-Output "Unable to find $ImportPath script unable to continue"
        Break
    }

    $Policies = Import-Csv -Path $ImportPath | Group-Object -Property Group
    foreach ($Policy in $Policies) {
        $Group = Get-IntuneGroup -Name $Policy.Name
        if ($null -eq $Group) {
            Write-Output "$($Policy.Name) group does not exist, unable to create EPM Policy"
            break
        }
        else {
            $Rules = $Policy.Group
            $JSONRules = @()
            $PolicyName = "EPM Policy for $($Group.displayName)"
            $PolicyDescription = "EPM Policy for $($Group.displayName) created on $Date by $User"
            if ($null -ne (Get-DeviceSettingsCatalog -EPM | Where-Object {$_.Name -eq $PolicyName})) {
                Write-Output "EPM policy $PolicyName already exists"
                break
            }
            $JSONPolicyStart = @"
        {
            "description": "$PolicyDescription",
            "name": "$PolicyName",
            "platforms": "windows10",
            "settings": [
              {
                "settingInstance": {
                  "@odata.type": "#microsoft.graph.deviceManagementConfigurationGroupSettingCollectionInstance",
                  "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}",
                  "settingInstanceTemplateReference": {
                    "settingInstanceTemplateId": "ee3d2e5f-6b3d-4cb1-af9b-37b02d3dbae2"
                  },
                  "groupSettingCollectionValue": [

"@
            $JSONPolicyEnd = @'
                        ]
                    }
                }
            ],
            "technologies": "endpointPrivilegeManagement",
            "templateReference": {
                "templateId": "cff02aad-51b1-498d-83ad-81161a393f56_1"
            }
        }
'@

            foreach ($Rule in $Rules) {
                $FileName = $Rule.FileName
                $FileInternalName = $Rule.FileInternalName
                $FilePath = $Rule.FilePath
                $FileHash = $Rule.FileHash
                $ElevationType = $Rule.ElevationType
                $FileProduct = $Rule.Product -replace '[^\x30-\x39\x41-\x5A\x61-\x7A]+', ' '
                $FileDescription = $Rule.Description
                $RuleDescription = $($Rule.Publisher + ' ' + $Rule.Description) -replace '[^\x30-\x39\x41-\x5A\x61-\x7A]+', ' '

                # First Rule needs TemplateIDs in the JSON
                if ($Rule -eq $Rules[0]) {

                    $JSONRuleStart = @"
                    {
                        "settingValueTemplateReference": null,
                        "children": [
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
                            "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_appliesto",
                            "settingInstanceTemplateReference": {
                                "settingInstanceTemplateId": "0cde1c42-c701-44b1-94b7-438dd4536128"
                            },
                            "choiceSettingValue": {
                            "value": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_allusers",
                            "settingValueTemplateReference": {
                                "settingValueTemplateId": "2ec26569-c08f-434c-af3d-a50ac4a1ce26",
                                "useTemplateDefault": false
                            },
                            "children": []
                            }
                        },
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                            "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_description",
                            "settingInstanceTemplateReference": {
                                "settingInstanceTemplateId": "b3714f3a-ead8-4682-a16f-ffa264c9d58f"
                            },
                            "simpleSettingValue": {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                            "value": "$RuleDescription",
                            "settingValueTemplateReference": {
                                "settingValueTemplateId": "5e82a1e9-ef4f-43ea-8031-93aace2ad14d",
                                "useTemplateDefault": false
                            }
                            }
                        },
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                            "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_productname",
                            "settingInstanceTemplateReference": {
                              "settingInstanceTemplateId": "234631a1-aeb1-436f-9e05-dcd9489caf08"
                            },
                            "simpleSettingValue": {
                              "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                              "value": "$FileProduct",
                              "settingValueTemplateReference": {
                                "settingValueTemplateId": "e466f96d-0633-40b3-86a4-9e093b696077",
                                "useTemplateDefault": false
                              }
                            }
                        },
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                            "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_internalname",
                            "settingInstanceTemplateReference": {
                              "settingInstanceTemplateId": "08511f12-25b5-4218-812c-39a2db444ef1"
                            },
                            "simpleSettingValue": {
                              "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                              "value": "$FileInternalName",
                              "settingValueTemplateReference": {
                                "settingValueTemplateId": "ec295dd4-6bbc-4fa8-a503-960784c53f41",
                                "useTemplateDefault": false
                              }
                            }
                        },
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                            "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_filehash",
                            "settingInstanceTemplateReference": {
                            "settingInstanceTemplateId": "e4436e2c-1584-4fba-8e38-78737cbbbfdf"
                            },
                            "simpleSettingValue": {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                            "value": "$FileHash",
                            "settingValueTemplateReference": {
                                "settingValueTemplateId": "1adcc6f7-9fa4-4ce3-8941-2ce22cf5e404",
                                "useTemplateDefault": false
                            }
                            }
                        },
"@

                    if ($ElevationType -eq 'Automatic') {
                        $TypeDescription = ' Automatically Approved'
                        $JSONRuleElev = @'
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
                            "choiceSettingValue": {
                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                                "children": [],
                                "settingValueTemplateReference": {
                                    "settingValueTemplateId": "cb2ea689-ebc3-42ea-a7a4-c704bb13e3ad"
                                },
                                "value": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_automatic"
                            },
                            "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_ruletype",
                            "settingInstanceTemplateReference": {
                                "settingInstanceTemplateId": "bc5a31ac-95b5-4ec6-be1f-50a384bb165f"
                            }
                        },
'@
                    }
                    elseif ($ElevationType -eq 'UserAuthentication') {
                        $TypeDescription = ' User Approved with Authentication '
                        $JSONRuleElev = @'
                            {
                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
                                "choiceSettingValue": {
                                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                                    "children": [
                                        {
                                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingCollectionInstance",
                                            "choiceSettingCollectionValue": [
                                                {
                                                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                                                    "children": [],
                                                    "value": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_ruletype_validation_1"
                                                }
                                            ],
                                            "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_ruletype_validation"
                                        }
                                    ],
                                    "settingValueTemplateReference": {
                                        "settingValueTemplateId": "cb2ea689-ebc3-42ea-a7a4-c704bb13e3ad"
                                    },
                                    "value": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_self"
                                },
                                "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_ruletype",
                                "settingInstanceTemplateReference": {
                                    "settingInstanceTemplateId": "bc5a31ac-95b5-4ec6-be1f-50a384bb165f"
                                }
                            },

'@
                    }
                    else {
                        $TypeDescription = ' User Approved with Business Justification'
                        $JSONRuleElev = @'
                            {
                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
                                "choiceSettingValue": {
                                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                                    "children": [
                                        {
                                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingCollectionInstance",
                                            "choiceSettingCollectionValue": [
                                                {
                                                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                                                    "children": [],
                                                    "value": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_ruletype_validation_0"
                                                }
                                            ],
                                            "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_ruletype_validation"
                                        }
                                    ],
                                    "settingValueTemplateReference": {
                                        "settingValueTemplateId": "cb2ea689-ebc3-42ea-a7a4-c704bb13e3ad"
                                    },
                                    "value": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_self"
                                },
                                "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_ruletype",
                                "settingInstanceTemplateReference": {
                                    "settingInstanceTemplateId": "bc5a31ac-95b5-4ec6-be1f-50a384bb165f"
                                }
                            },

'@
                    }

                    $JSONRuleEnd = @"
                            {
                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                                "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_filedescription",
                                "settingInstanceTemplateReference": {
                                "settingInstanceTemplateId": "5e10c5a9-d3ca-4684-b425-e52238cf3c8b"
                                },
                                "simpleSettingValue": {
                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                                "value": "$FileDescription",
                                "settingValueTemplateReference": {
                                    "settingValueTemplateId": "df3081ea-4ea7-4f34-ac87-49b2e84d4c4b",
                                    "useTemplateDefault": false
                                }
                                }
                            },
                            {
                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                                "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_name",
                                "settingInstanceTemplateReference": {
                                "settingInstanceTemplateId": "fdabfcf9-afa4-4dbf-a4ef-d5c1549065e1"
                                },
                                "simpleSettingValue": {
                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                                "value": "$FileDescription $TypeDescription",
                                "settingValueTemplateReference": {
                                    "settingValueTemplateId": "03f003e5-43ef-4e7e-bf30-57f00781fdcc",
                                    "useTemplateDefault": false
                                }
                                }
                            },
                            {
                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                                "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_filename",
                                "settingInstanceTemplateReference": {
                                "settingInstanceTemplateId": "0c1ceb2b-bbd4-46d4-9ba5-9ee7abe1f094"
                                },
                                "simpleSettingValue": {
                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                                "value": "$FileName",
                                "settingValueTemplateReference": {
                                    "settingValueTemplateId": "a165327c-f0e5-4c7d-9af1-d856b02191f7",
                                    "useTemplateDefault": false
                                }
                                }
                            },
                            {
                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                                "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_filepath",
                                "settingInstanceTemplateReference": {
                                "settingInstanceTemplateId": "c3b7fda4-db6a-421d-bf04-d485e9d0cfb1"
                                },
                                "simpleSettingValue": {
                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                                "value": "$FilePath",
                                "settingValueTemplateReference": {
                                    "settingValueTemplateId": "f011bcfc-03cd-4b28-a1f4-305278d7a030",
                                    "useTemplateDefault": false
                                }
                                }
                            }
                        ]
"@

                }

                # Additional Rules has different JSON format with no TemplateID
                else {

                    $JSONRuleStart = @"
                {
                    "settingValueTemplateReference": null,
                    "children": [
                      {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
                        "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_appliesto",
                        "settingInstanceTemplateReference": null,
                        "choiceSettingValue": {
                          "settingValueTemplateReference": null,
                          "value": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_allusers",
                          "children": []
                        }
                      },
                      {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                        "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_description",
                        "settingInstanceTemplateReference": null,
                        "simpleSettingValue": {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$RuleDescription"
                        }
                    },
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                        "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_productname",
                        "settingInstanceTemplateReference": null,
                        "simpleSettingValue": {
                          "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                          "settingValueTemplateReference": null,
                          "value": "$FileProduct"
                        }
                    },
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                        "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_internalname",
                        "settingInstanceTemplateReference": null,
                        "simpleSettingValue": {
                          "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                          "settingValueTemplateReference": null,
                          "value": "$FileInternalName"
                        }
                    },
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                        "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_filehash",
                        "settingInstanceTemplateReference": null,
                        "simpleSettingValue": {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                        "settingValueTemplateReference": null,
                        "value": "$FileHash"
                        }
                    },
"@

                    if ($ElevationType -eq 'Automatic') {
                        $TypeDescription = 'Automatically approved '
                        $JSONRuleElev = @'
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
                            "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_ruletype",
                            "settingInstanceTemplateReference": null,
                            "choiceSettingValue": {
                            "settingValueTemplateReference": null,
                            "value": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_automatic",
                            "children": []
                            }
                        },
'@
                    }
                    elseif ($ElevationType -eq 'UserAuthentication') {
                        $TypeDescription = 'User approved with Authentication '
                        $JSONRuleElev = @'
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
                            "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_ruletype",
                            "settingInstanceTemplateReference": null,
                            "choiceSettingValue": {
                            "settingValueTemplateReference": null,
                            "value": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_self",
                            "children": [
                                {
                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingCollectionInstance",
                                "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_ruletype_validation",
                                "settingInstanceTemplateReference": null,
                                "choiceSettingCollectionValue": [
                                    {
                                    "settingValueTemplateReference": null,
                                    "value": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_ruletype_validation_1",
                                    "children": []
                                    }
                                ]
                                }
                            ]
                            }
                        },
'@
                    }
                    else {
                        $TypeDescription = 'User approved with Business Justification '
                        $JSONRuleElev = @'
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
                            "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_ruletype",
                            "settingInstanceTemplateReference": null,
                            "choiceSettingValue": {
                            "settingValueTemplateReference": null,
                            "value": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_self",
                            "children": [
                                {
                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingCollectionInstance",
                                "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_ruletype_validation",
                                "settingInstanceTemplateReference": null,
                                "choiceSettingCollectionValue": [
                                    {
                                    "settingValueTemplateReference": null,
                                    "value": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_ruletype_validation_0",
                                    "children": []
                                    }
                                ]
                                }
                            ]
                            }
                        },

'@
                    }

                    $JSONRuleEnd = @"
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                            "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_filedescription",
                            "settingInstanceTemplateReference": null,
                            "simpleSettingValue": {
                              "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                              "settingValueTemplateReference": null,
                              "value": "$FileDescription"
                            }
                        },
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                            "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_name",
                            "settingInstanceTemplateReference": null,
                            "simpleSettingValue": {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                            "settingValueTemplateReference": null,
                            "value": "$FileDescription $TypeDescription"
                            }
                        },
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                            "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_filename",
                            "settingInstanceTemplateReference": null,
                            "simpleSettingValue": {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                            "settingValueTemplateReference": null,
                            "value": "$FileName"
                            }
                        },
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                            "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_filepath",
                            "settingInstanceTemplateReference": null,
                            "simpleSettingValue": {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                            "settingValueTemplateReference": null,
                            "value": "$FilePath"
                            }
                        }
                    ]
"@

                }

                # Last rule in the set
                if ($Rule -eq $Rules[-1]) {
                    $JSONRuleEnding = @'
                }
'@
                }
                # Not last rule in the set
                else {
                    $JSONRuleEnding = @'
                },

'@
                }

                # Combines the rule
                $JSONRule = $JSONRuleStart + $JSONRuleElev + $JSONRuleEnd + $JSONRuleEnding

                # Adds the rule to the set of rules
                $JSONRules += $JSONRule
            }

            # Combines all JSON ready to push to Graph
            $JSONOutput = $JSONPolicyStart + $JSONRules + $JSONPolicyEnd
            $EPMPolicy = New-DeviceSettingsCatalog -JSON $JSONOutput
            Write-Output "Successfully created $($EPMPolicy.name)"

            if ($Deployment -eq 'ImportAssign') {
                Add-DeviceSettingsCatalogAssignment -id $EPMPolicy.id -TargetGroupId $Group.id -AssignmentType Include -Name $EPMPolicy.name
            }
        }
    }
}
