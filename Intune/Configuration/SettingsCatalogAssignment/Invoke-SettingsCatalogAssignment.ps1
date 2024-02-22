#region Functions
Function Get-AuthTokenMSAL() {

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
        Write-Warning 'MSAL.PS Powershell module not installed...'
        Write-Warning "Install by running 'Install-Module MSAL.PS -Scope CurrentUser' from an elevated PowerShell prompt"
        WriteWrite-Warning-Host "Script can't continue..."
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
            Write-Warning 'Authorization Access Token is null, please re-run authentication'
            break
        }
    }
    catch {
        Write-Host $_.Exception.Message
        Write-Host $_.Exception.ItemName
        break
    }
}
Function Get-MDMGroup() {

    <#
    .SYNOPSIS
    This function is used to get AAD groups using Graph API
    .DESCRIPTION
    The function gets Azure AD groups by searching for the group display name
    .EXAMPLE
    Get-MDMGroup -Name 'SG_MEM'
    Get-MDMGroup -Name 'SG_MEM_Devices_Coporate_POC'
    .NOTES
    NAME: Get-MDMGroup
    #>

    [cmdletbinding()]

    param
    (
        [parameter(Mandatory = $true)]
        [string]$GroupName
    )

    $graphApiVersion = 'beta'
    $Resource = 'groups'

    try {
        $authToken['ConsistencyLevel'] = 'eventual'
        $searchterm = 'search="displayName:' + $GroupName + '"'
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource`?$searchterm"
        (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
    }
    catch {
        $exs = $Error.ErrorDetails
        $ex = $exs[0]
        Write-Host "Response content:`n$ex"
        Write-Host "Request to $Uri failed with HTTP Status $($ex.Message)"
        Break
    }
}
Function Get-DeviceFilter() {

    <#
    .SYNOPSIS
    This function is used to get Intune Device Filters groups using Graph API
    .DESCRIPTION
    The function gets All Device Filters, or a specific Device Filter based on name or id
    .EXAMPLE
    Get-DeviceFilter
    Get-DeviceFilter -Name 'Corporate_All'
    Get-DeviceFilter -Id 'dee985c2-0e4e-4c70-9a13-186f3313fc14'
    .NOTES
    NAME: Get-DeviceFilter
    #>

    [cmdletbinding()]

    param (

        [Parameter(Mandatory = $false)]
        $Name,

        [Parameter(Mandatory = $false)]
        $Id

    )

    $graphApiVersion = 'beta'
    $Resource = 'deviceManagement/assignmentFilters'

    try {
        if ($id) {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)/$id"
            Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get
        }
        elseif ($Name) {

            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value | Where-Object { ($_.displayName).contains("$Name") }
        }
        else {
            $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).Value
        }
    }
    catch {
        $exs = $Error.ErrorDetails
        $ex = $exs[0]
        Write-Host "Response content:`n$ex"
        Write-Host "Request to $Uri failed with HTTP Status $($ex.Message)"
        Break
    }
}
Function Get-DeviceSettingsCatalogAssignment() {

    [cmdletbinding()]

    param
    (
        [parameter(Mandatory = $true)]
        $Id
    )

    $graphApiVersion = 'Beta'
    $Resource = "deviceManagement/configurationPolicies/$Id/assignments"

    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        (Invoke-RestMethod -Uri $uri -Headers $authToken -Method Get).value
    }
    catch {
        $exs = $Error.ErrorDetails
        $ex = $exs[0]
        Write-Host "Response content:`n$ex"
        Write-Host "Request to $Uri failed with HTTP Status $($ex.Message)"
        Break
    }
}
Function Get-DeviceSettingsCatalog() {

    [cmdletbinding()]

    param (

        [Parameter(Mandatory = $false)]
        $Name,

        [Parameter(Mandatory = $false)]
        $Id

    )

    $graphApiVersion = 'beta'
    $Resource = "deviceManagement/configurationPolicies?`$filter=technologies has 'mdm'"

    try {
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
        Write-Host "Response content:`n$ex"
        Write-Host "Request to $Uri failed with HTTP Status $($ex.Message)"
        Break
    }
}
Function Add-DeviceSettingsCatalogAssignment() {

    [cmdletbinding()]

    param
    (
        [parameter(Mandatory = $true)]
        [string]$Id,

        [parameter(Mandatory = $false)]
        [string]$GroupId,

        [parameter(Mandatory = $true)]
        [ValidateSet('Include', 'Exclude')]
        [string]$AssignmentType,

        [parameter(Mandatory = $false)]
        [string]$FilterId,

        [parameter(Mandatory = $false)]
        [ValidateSet('Include', 'Exclude')]
        [string]$FilterType,

        [parameter(Mandatory = $false)]
        [ValidateSet('Users', 'Devices')]
        [string]$All,

        [parameter(Mandatory = $true)]
        [ValidateSet('Replace', 'Add')]
        $AssignmentAction
    )

    $graphApiVersion = 'Beta'
    $Resource = "deviceManagement/configurationPolicies/$Id/assign"

    try {
        # Stopping assignmnent of All Users or All Devices as an exclude assignment
        if (($All -ne '') -and ($AssignmentType -eq 'Exclude')) {
            Write-Warning 'You cannot All Devices or All Users groups as an exclude assignment'
            break
        }
        # Stopping assignment of group and All Devices/Users
        if (($All -ne '') -and ($GroupId -ne '')) {
            Write-Warning 'You cannot assign to All Devices or All Users, and groups'
            break
        }
        # Stopping assignment of group with filter as an exclude assignment
        if (($AssignmentType -eq 'Exclude') -and ($GroupId -ne '') -and ($FilterId -ne '')) {
            Write-Warning 'You cannot assign a group with a filter as an exclude assignment'
            break
        }

        # If Adding an assignment to existing assignments
        If ($AssignmentAction -eq 'Add') {
            # Checking if there are Assignments already configured
            $Assignments = Get-DeviceSettingsCatalogAssignment -Id $Id
            if ($Assignments.count -ge 1) {
                # Checking if the group is already assigned
                If (($GroupId -ne '') -and ($GroupId -in $Assignments.target.groupId)) {
                    Write-Warning 'The policy is already assigned to the Group'
                    break
                }
                # Checking if already assigned to All Devices
                ElseIf (($All -eq 'Devices') -and ($Assignments.target.'@odata.type' -contains '#microsoft.graph.allDevicesAssignmentTarget')) {
                    Write-Warning 'The policy is already assigned to the All Devices group'
                    break
                }
                # Checking if aleady assigned to All users
                ElseIf (($All -eq 'Users') -and ($Assignments.target.'@odata.type' -contains '#microsoft.graph.allLicensedUsersAssignmentTarget')) {
                    Write-Warning 'The policy is already assigned to the All Users group'
                    break
                }
                # Checking if already assigned to groups when assigning 'All' assignment
                ElseIf (($All -ne '') -and ($Assignments.target.'@odata.type' -contains '#microsoft.graph.groupAssignmentTarget')) {
                    Write-Warning 'The policy is already assigned to a group(s), and cannot be assigned to All Devices or All Users groups'
                    break
                }
                # Checking if already assigned to 'All' when assigning groups
                ElseIf (($GroupId -ne '') -and (($Assignments.target.'@odata.type' -contains '#microsoft.graph.allDevicesAssignmentTarget') -or ($Assignments.target.'@odata.type' -contains '#microsoft.graph.allLicensedUsersAssignmentTarget'))) {
                    Write-Warning 'The policy is already assigned to All Devices or All Users groups, and cannot be assigned to a group'
                    break
                }
                # If new assignment viable, captures existing assignments
                Else {
                    # Creates an array for the existing assignments
                    $TargetGroups = @()
                    foreach ($Assignment in $Assignments) {
                        $TargetGroup = New-Object -TypeName psobject

                        $TargetGroup | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value $Assignment.target.'@odata.type'

                        if ($Assignment.target.'@odata.type' -like '*groupAssignmentTarget*') {
                            $TargetGroup | Add-Member -MemberType NoteProperty -Name 'groupId' -Value $Assignment.target.groupId
                        }

                        if ($Assignment.target.deviceAndAppManagementAssignmentFilterType -ne 'none') {
                            $TargetGroup | Add-Member -MemberType NoteProperty -Name 'deviceAndAppManagementAssignmentFilterId' -Value $Assignment.target.deviceAndAppManagementAssignmentFilterId
                            $TargetGroup | Add-Member -MemberType NoteProperty -Name 'deviceAndAppManagementAssignmentFilterType' -Value $Assignment.target.deviceAndAppManagementAssignmentFilterType
                        }

                        $Target = New-Object -TypeName psobject
                        $Target | Add-Member -MemberType NoteProperty -Name 'target' -Value $TargetGroup
                        $TargetGroups += $Target
                    }
                }
            }
        }

        # Creates the new assignment
        $TargetGroup = New-Object -TypeName psobject

        if ($GroupId) {
            if ($AssignmentType -eq 'Exclude') {
                $TargetGroup | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.exclusionGroupAssignmentTarget'
            }
            elseif ($AssignmentType -eq 'Include') {
                $TargetGroup | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.groupAssignmentTarget'
            }

            $TargetGroup | Add-Member -MemberType NoteProperty -Name 'groupId' -Value "$GroupId"
        }
        else {
            if ($All -eq 'Users') {
                $TargetGroup | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.allLicensedUsersAssignmentTarget'
            }
            ElseIf ($All -eq 'Devices') {
                $TargetGroup | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.allDevicesAssignmentTarget'
            }
        }

        if ($FilterType) {
            $TargetGroup | Add-Member -MemberType NoteProperty -Name 'deviceAndAppManagementAssignmentFilterId' -Value $FilterId
            $TargetGroup | Add-Member -MemberType NoteProperty -Name 'deviceAndAppManagementAssignmentFilterType' -Value $FilterType
        }

        $Target = New-Object -TypeName psobject
        $Target | Add-Member -MemberType NoteProperty -Name 'target' -Value $TargetGroup
        $TargetGroups += $Target

        # Creating JSON object to pass to Graph
        $Output = New-Object -TypeName psobject
        $Output | Add-Member -MemberType NoteProperty -Name 'assignments' -Value @($TargetGroups)
        $JSON = $Output | ConvertTo-Json -Depth 3

        # POST to Graph Service
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        Invoke-RestMethod -Uri $uri -Headers $authToken -Method Post -Body $JSON -ContentType 'application/json'
    }
    catch {
        $exs = $Error.ErrorDetails
        $ex = $exs[0]
        Write-Host "Response content:`n$ex" -f Red
        Write-Host "Request to $Uri failed with HTTP Status $($ex.Message)"
        Break
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
        Write-Host "Authentication Token expired $TokenExpires minutes ago"

        # Defining User Principal Name if not present
        if ($null -eq $User -or $User -eq '') {
            $User = Read-Host -Prompt 'Please specify your user principal name for Azure Authentication'
        }
        $global:authToken = Get-AuthTokenMSAL -User $User
    }
}
# Authentication doesn't exist, calling Get-AuthToken function
else {
    if ($null -eq $User -or $User -eq '') {
        $User = Read-Host -Prompt 'Please specify your user principal name for Azure Authentication'
    }
    # Getting the authorization token
    $global:authToken = Get-AuthTokenMSAL -User $User
    Write-Host 'Connected to Graph API'
}

#endregion

# Get Settings Catalog
$Policy = Get-DeviceSettingsCatalog | Where-Object { $_.Name -eq 'Corporate_Configuration_Policy_Conflict' }

$id = $Policy.id

Get-DeviceSettingsCatalogAssignment -Id '0565e69e-7bba-455a-bfaa-4ca6680a02b5' | fl

# Getting group to assign
$Group = Get-MDMGroup -GroupName 'SG_MDM_Devices_Corporate_POC'

# Getting Device Filter
$Filter = Get-DeviceFilter -Name 'Corporate_Windows_All'

# Adding an include Group assignment
Add-DeviceSettingsCatalogAssignment -Id $Policy.id -AssignmentAction Add -AssignmentType Include -GroupId $group.id

# Adding an include Group assignment with include filter
Add-DeviceSettingsCatalogAssignment -Id $Policy.id -AssignmentAction Add -AssignmentType Include -GroupId $group.id -FilterType Include -FilterID $Filter.id

# Adding an exclude Group assignment
Add-DeviceSettingsCatalogAssignment -Id $Policy.id -AssignmentAction Add -AssignmentType Exclude -GroupId $group.id

# Adding an Include All Devices assignment
Add-DeviceSettingsCatalogAssignment -Id $Policy.id -AssignmentAction Add -AssignmentType Include -All Devices

# Adding an Include All Devices assignment with filter
Add-DeviceSettingsCatalogAssignment -Id $Policy.id -AssignmentAction Add -AssignmentType Include -All Devices -FilterType Include -FilterID $Filter.id

# Replacing all assignment and adding an Include All Users assignment
Add-DeviceSettingsCatalogAssignment -Id $Policy.id -AssignmentAction Replace -AssignmentType Include -All Users
