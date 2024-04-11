<#
.SYNOPSIS
Allows for a phased and controlled distribution of Windows 11 Feature Updates
following the run and capture of Update Readiness data, tagging devices
in Entra ID with their update readiness risk score for use with Dynamic
Security Groups.

.DESCRIPTION
The Invoke-Windows11Accelerator script allows for the controlled roll out of
Windows 11 Feature Updates based on device readiness risk assements data.

.PARAMETER tenantId
Provide the Id of the tenant to connecto to.

.PARAMETER Scopes
The scopes used to connect to the Graph API using PowerShell.
Default scopes configured are:
'Group.Read.All,DeviceManagementConfiguration.ReadWrite.All,DeviceManagementManagedDevices.ReadWrite.All'

.PARAMETER deployment
Provide the type of deployment, select from:
Report - Generates and downloads EPM report details.
Import - Allows the import of new rules based on the report.
ImportAssign - Allows the import of new rules based on the report and assignment based on provided group.

.INPUTS
None. You can't pipe objects to Invoke-MgEPNRulesUpdate.

.OUTPUTS
None. Invoke-MgEPNRulesUpdate doesn't generate any output.

.EXAMPLE
PS> .\Invoke-MgEPNRulesUpdate.ps1 -tenantId 36019fe7-a342-4d98-9126-1b6f94904ac7 -deployment Report

.EXAMPLE
PS> .\Invoke-MgEPNRulesUpdate.ps1 -tenantId 36019fe7-a342-4d98-9126-1b6f94904ac7 -deployment Import

#>

[CmdletBinding()]
param(

    [Parameter(Mandatory = $true)]
    [String]$tenantId = '12dddf86-ad8c-4563-a980-18d4c5321b6a',

    [Parameter(Mandatory = $false)]
    [String[]]$scopes = 'Group.Read.All,DeviceManagementConfiguration.ReadWrite.All,DeviceManagementManagedDevices.ReadWrite.All',

    [Parameter(Mandatory = $true)]
    [ValidateSet('Report', 'Import', 'ImportAssign')]
    [string]$deployment

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
Function Get-DeviceEPMReport() {

    [cmdletbinding()]

    param (

        [Parameter(Mandatory = $false)]
        [ValidateSet('Managed', 'Unmanaged')]
        [String]$elevation,

        [Parameter(Mandatory = $false)]
        $Top

    )

    $graphApiVersion = 'beta'
    $Resource = 'deviceManagement/privilegeManagementElevations'

    try {
        if ($elevation -eq 'Managed') {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?filter=(elevationType ne 'unmanagedElevation')"
            (Invoke-MgGraphRequest -Uri $uri -Method Get).value
        }
        elseif ($elevation -eq 'Unmanaged') {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)?filter=(elevationType eq 'unmanagedElevation')"
            (Invoke-MgGraphRequest -Uri $uri -Method Get).value
        }
        else {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get).value
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

        $searchterm = 'search="displayName:' + $Name + '"'
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource`?$searchterm"
        (Invoke-MgGraphRequest -Headers @{ConsistencyLevel = 'eventual' } -Uri $uri -Method Get).Value
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
            (Invoke-MgGraphRequest -Uri $uri -Method Get).Value
        }
        if ($Id) {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource/$Id"
            Invoke-MgGraphRequest -Uri $uri -Method Get
        }
        elseif ($Name) {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get).Value | Where-Object { ($_.Name).contains("$Name") }
        }
        Else {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get).Value
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
        Invoke-MgGraphRequest -Uri $uri -Method Post -Body $JSON -ContentType 'application/json'
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
        Invoke-MgGraphRequest -Uri $uri -Method Post -Body $JSON -ContentType 'application/json'
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

$date = (Get-Date -Format 'yyyy_MM_dd_HH_mm_ss').ToString()
$reportPath = 'C:\Source\github\mve-scripts\Intune\EndpointSecurity\EPMAutomation'
$importPath = 'C:\Source\github\mve-scripts\Intune\EndpointSecurity\EPMAutomation\EPM_Report_2024_04_03_13_13_03.csv'

$elevationTypes = @('Automatic', 'UserAuthentication', 'UserJustification', 'SupportApproved')
$childProcessBehaviours = @('AllowAll', 'RequireRule', 'DenyAll', 'NotConfigured')

#region Report
if ($deployment -eq 'Report') {
    $reportPath = Read-Host -Prompt "Please specify a path to export the EPM data to e.g., 'C:\Temp'"
    if (!(Test-Path "$reportPath")) {
        New-Item -ItemType Directory -Path "$reportPath" | Out-Null
    }
    $csvFile = "$reportPath\EPM_Report_$date.csv"
    $epmReport = @()
    $hashes = Get-DeviceEPMReport | Group-Object -Property hash
    foreach ($hash in $hashes) {

        $elevations = $hash.Group
        $users = @()
        $devices = @()

        foreach ($elevation in $elevations) {
            $fileName = $elevation.filePath | Split-Path -Leaf
            $fileInternalName = $elevation.internalName
            $fileCompany = $elevation.companyName
            $fileProduct = $elevation.productName
            $fileDescription = $elevation.fileDescription
            $filePath = ($elevation.filePath | Split-Path) -replace '\\', '\\'
            $fileVersion = $elevation.fileVersion
            $users += $elevation.upn
            $devices += $elevation.deviceName
        }

        $Data = [PSCustomObject]@{
            ElevationCount        = $hash.Count
            Product               = $fileProduct
            Description           = $fileDescription
            Publisher             = $fileCompany
            FileName              = $fileName
            FileInternalName      = $fileInternalName
            FileVersion           = $fileVersion
            FilePath              = $filePath
            FileHash              = $hash.Name
            Users                 = (($users | Get-Unique) -join ' ' | Out-String).Trim()
            Devices               = (($devices | Get-Unique) -join ' ' | Out-String).Trim()
            ElevationType         = $($elevationTypes -join '/')
            ChildProcessBehaviour = $($childProcessBehaviours -join '/')
            Group                 = 'GroupName'
        }

        $epmReport += $Data
    }

    # CSV Report
    $epmReport | Export-Csv -Path $csvFile -NoTypeInformation
    Write-Host "Report exported to $csvFile" -ForegroundColor Green
}
#endregion Report

#region Import
elseif ($deployment -like '*Import*') {
    $importPath = Read-Host -Prompt 'Please specify a path to EPM data CSV to e.g., C:\Temp\EPM_Data.csv'
    if (!(Test-Path "$importPath")) {
        Write-Host "Unable to find $importPath script unable to continue"
        Break
    }

    $policies = Import-Csv -Path $importPath | Group-Object -Property Group

    #region Validation
    Write-Host 'Beginning validation of the imported policies.' -ForegroundColor Cyan
    $issuesElevationType = 0
    $issuesChildProcessBehaviour = 0
    $issuesGroup = 0
    foreach ($policy in $policies) {
        $rules = $policy.Group
        foreach ($rule in $rules) {
            if ($rule.ElevationType -notin $elevationTypes) {
                $issuesElevationType++
            }
            if ($rule.ChildProcessBehaviour -notin $childProcessBehaviours) {
                $issuesChildProcessBehaviour++
            }
        }

        if ($deployment -eq 'ImportAssign') {
            $group = Get-IntuneGroup -Name $policy.Name
            if ($null -eq $group) {
                $issuesGroup++
            }
        }
    }
    Write-Host 'Completed validation of the imported policies.' -ForegroundColor Green

    If ($issuesElevationType -ne 0) {
        Write-Host "Incorrect Evalation type specified in the report, please review the import file and use one of the following settings $($elevationTypes -join '/') for elevation type." -ForegroundColor Yellow
        Break
    }
    If ($issuesChildProcessBehaviour -ne 0) {
        Write-Host "Incorrect Child Process Behaviour type specified in the report, please review the import file and use one of the following settings $($childProcessBehaviours -join '/') for behaviour type." -ForegroundColor Yellow
        Break
    }
    If ($issuesGroup -ne 0) {
        Write-Host 'Incorrect Group Names specified in the report, please review the import file and ensure the correct Group is configured.' -ForegroundColor Yellow
        Break
    }
    #endregion Validation

    foreach ($policy in $policies) {
        $group = Get-IntuneGroup -Name $policy.Name
        $rules = $policy.Group
        $JSONRules = @()
        $policyName = "EPM Policy for $($group.displayName)"
        $PolicyDescription = "EPM Policy for $($group.displayName) created on $date"
        if ($null -ne (Get-DeviceSettingsCatalog -EPM | Where-Object { $_.Name -eq $policyName })) {
            Write-Host "EPM policy $policyName already exists" -ForegroundColor Yellow
            break
        }
        $JSONPolicyStart = @"
        {
            "description": "$PolicyDescription",
            "name": "$policyName",
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

        foreach ($rule in $rules) {
            $fileName = $rule.FileName
            $fileInternalName = $rule.FileInternalName
            $filePath = $rule.FilePath
            $fileHash = $rule.FileHash
            $elevationType = $rule.ElevationType
            $childProcess = $rule.ChildProcessBehaviour
            $fileProduct = $rule.Product -replace '[^\x30-\x39\x41-\x5A\x61-\x7A]+', ' '
            $fileDescription = $rule.Description
            $ruleDescription = $($rule.Publisher + ' ' + $rule.Description) -replace '[^\x30-\x39\x41-\x5A\x61-\x7A]+', ' '

            # First Rule needs TemplateIDs in the JSON
            if ($rule -eq $rules[0]) {

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
                            "value": "$ruleDescription",
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
                                "value": "$fileProduct",
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
                                "value": "$fileInternalName",
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
                            "value": "$fileHash",
                            "settingValueTemplateReference": {
                                "settingValueTemplateId": "1adcc6f7-9fa4-4ce3-8941-2ce22cf5e404",
                                "useTemplateDefault": false
                            }
                            }
                        },

"@

                switch ($elevationType) {
                    'Automatic' {
                        $typeDescription = ' Automatically Approved'
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
                    'UserAuthentication' {
                        $typeDescription = ' User Approved with Authentication '
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
                    'UserJustification' {
                        $typeDescription = ' User Approved with Business Justification'
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
                    'SupportApproved' {
                        $typeDescription = ' Support Approved'
                        $JSONRuleElev = @'
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
                            "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_ruletype",
                            "choiceSettingValue":
                                {
                                    "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                                    "value": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_supportarbitrated",
                                    "children": [],
                                    "settingValueTemplateReference":
                                        {
                                        "settingValueTemplateId": "cb2ea689-ebc3-42ea-a7a4-c704bb13e3ad",
                                        },
                                },
                            "settingInstanceTemplateReference":
                                {
                                    "settingInstanceTemplateId": "bc5a31ac-95b5-4ec6-be1f-50a384bb165f",
                                },
                        },

'@
                    }
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
                                "value": "$fileDescription",
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
                                "value": "$fileDescription $typeDescription",
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
                                "value": "$fileName",
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
                                "value": "$filePath",
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
                                "value": "$ruleDescription"
                            }
                        },
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                            "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_productname",
                            "settingInstanceTemplateReference": null,
                            "simpleSettingValue": {
                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                                "settingValueTemplateReference": null,
                                "value": "$fileProduct"
                            }
                        },
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                            "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_internalname",
                            "settingInstanceTemplateReference": null,
                            "simpleSettingValue": {
                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                                "settingValueTemplateReference": null,
                                "value": "$fileInternalName"
                            }
                        },
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                            "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_filehash",
                            "settingInstanceTemplateReference": null,
                            "simpleSettingValue": {
                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                                "settingValueTemplateReference": null,
                                "value": "$fileHash"
                            }
                    },

"@

                switch ($elevationType) {
                    'Automatic' {
                        $typeDescription = ' Automatically Approved'
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
                    'UserAuthentication' {
                        $typeDescription = ' User Approved with Authentication '
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
                    'UserJustification' {
                        $typeDescription = ' User Approved with Business Justification'
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
                    'SupportApproved' {
                        $typeDescription = ' Support Approved'
                        $JSONRuleElev = @'
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
                            "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_ruletype",
                            "choiceSettingValue": {
                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                                "value": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_supportarbitrated",
                                "children": []
                            }
                        },

'@
                    }
                }

                $JSONRuleEnd = @"
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                            "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_filedescription",
                            "settingInstanceTemplateReference": null,
                            "simpleSettingValue": {
                                "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                                "settingValueTemplateReference": null,
                                "value": "$fileDescription"
                            }
                        },
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                            "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_name",
                            "settingInstanceTemplateReference": null,
                            "simpleSettingValue": {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                            "settingValueTemplateReference": null,
                            "value": "$fileDescription $typeDescription"
                            }
                        },
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                            "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_filename",
                            "settingInstanceTemplateReference": null,
                            "simpleSettingValue": {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                            "settingValueTemplateReference": null,
                            "value": "$fileName"
                            }
                        },
                        {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationSimpleSettingInstance",
                            "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_filepath",
                            "settingInstanceTemplateReference": null,
                            "simpleSettingValue": {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationStringSettingValue",
                            "settingValueTemplateReference": null,
                            "value": "$filePath"
                            }
                        }
                    ]

"@

            }

            # Child Process behaviour is the same across all rules
            switch ($childProcess) {
                'AllowAll' {
                    $JSONRuleChild = @'
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
                        "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_childprocessbehavior",
                        "choiceSettingValue": {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                            "value": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_allowrunelevated",
                            "children": []
                        }
                    },

'@
                }
                'RequireRule' {
                    $JSONRuleChild = @'
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
                        "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_childprocessbehavior",
                        "choiceSettingValue": {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                            "value": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_allowrunelevatedrulerequired",
                            "children": []
                        }
                    },

'@
                }
                'DenyAll' {
                    $JSONRuleChild = @'
                    {
                        "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingInstance",
                        "settingDefinitionId": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_childprocessbehavior",
                        "choiceSettingValue": {
                            "@odata.type": "#microsoft.graph.deviceManagementConfigurationChoiceSettingValue",
                            "value": "device_vendor_msft_policy_privilegemanagement_elevationrules_{elevationrulename}_deny",
                            "children": []
                        }
                    },

'@
                }
                'NotConfigured' {
                    $JSONRuleChild = @'
'@
                }
            }

            # Last rule in the set
            if ($rule -eq $rules[-1]) {
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
            $JSONRule = $JSONRuleStart + $JSONRuleElev + $JSONRuleChild + $JSONRuleEnd + $JSONRuleEnding

            # Adds the rule to the set of rules
            $JSONRules += $JSONRule
        }

        # Combines all JSON ready to push to Graph
        $JSONOutput = $JSONPolicyStart + $JSONRules + $JSONPolicyEnd
        $EPMPolicy = New-DeviceSettingsCatalog -JSON $JSONOutput
        Write-Host "Successfully created $($EPMPolicy.name)" -ForegroundColor Green

        if ($deployment -eq 'ImportAssign') {
            Add-DeviceSettingsCatalogAssignment -Id $EPMPolicy.id -TargetGroupId $group.id -AssignmentType Include -Name $EPMPolicy.name
        }

    }
}
#endregion Import
