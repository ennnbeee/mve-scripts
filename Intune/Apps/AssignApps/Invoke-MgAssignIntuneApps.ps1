#region Functions
[CmdletBinding()]

param(

    [Parameter(Mandatory = $true)]
    [String]$tenantId,

    [Parameter(Mandatory = $false)]
    [String[]]$scopes = 'DeviceManagementConfiguration.Read.All,DeviceManagementManagedDevices.ReadWrite.All,DeviceManagementConfiguration.ReadWrite.All'

)
#region Functions

Function Get-MobileApps() {
    [cmdletbinding()]
    $graphApiVersion = 'Beta'
    $Resource = 'deviceAppManagement/mobileApps'
    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get).Value
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Get-DeviceFilter() {

    $graphApiVersion = 'beta'
    $Resource = 'deviceManagement/assignmentFilters'

    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
            (Invoke-MgGraphRequest -Uri $uri -Method Get).Value
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Get-MDMGroup() {

    [cmdletbinding()]

    param
    (
        [parameter(Mandatory = $true)]
        [string]$GroupName
    )

    $graphApiVersion = 'beta'
    $Resource = 'groups'

    try {
        $searchterm = 'search="displayName:' + $GroupName + '"'
        $uri = "https://graph.microsoft.com/$graphApiVersion/$Resource`?$searchterm"
        (Invoke-MgGraphRequest -Uri $uri -Method Get -Headers @{ConsistencyLevel = 'eventual' }).Value
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Get-ApplicationAssignment() {

    [cmdletbinding()]

    param
    (
        [parameter(Mandatory = $true)]
        $Id
    )

    $graphApiVersion = 'Beta'
    $Resource = "deviceAppManagement/mobileApps/$Id/?`$expand=categories,assignments"

    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        (Invoke-MgGraphRequest -Uri $uri -Method Get)
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Remove-ApplicationAssignment() {

    [cmdletbinding()]

    param
    (
        [parameter(Mandatory = $true)]
        $Id,
        [parameter(Mandatory = $true)]
        $AssignmentId
    )

    $graphApiVersion = 'Beta'
    $Resource = "deviceAppManagement/mobileApps/$Id/assignments/$AssignmentId"

    try {
        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        (Invoke-MgGraphRequest -Uri $uri -Method Delete)
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}
Function Add-ApplicationAssignment() {

    [cmdletbinding()]

    param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $Id,

        [parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        $TargetGroupId,

        [parameter(Mandatory = $true)]
        [ValidateSet('Available', 'Required')]
        [ValidateNotNullOrEmpty()]
        $InstallIntent,

        $FilterID,

        [ValidateSet('Include', 'Exclude')]
        $FilterMode,

        [parameter(Mandatory = $false)]
        [ValidateSet('Users', 'Devices')]
        [ValidateNotNullOrEmpty()]
        $All,

        [parameter(Mandatory = $true)]
        [ValidateSet('Replace', 'Add')]
        $Action
    )

    $graphApiVersion = 'beta'
    $Resource = "deviceAppManagement/mobileApps/$Id/assign"

    try {
        $TargetGroups = @()

        If ($Action -eq 'Add') {
            # Checking if there are Assignments already configured
            $Assignments = (Get-ApplicationAssignment -Id $Id).assignments
            if (@($Assignments).count -ge 1) {
                foreach ($Assignment in $Assignments) {

                    If (($null -ne $TargetGroupId) -and ($TargetGroupId -eq $Assignment.target.groupId)) {
                        Write-Host 'The App is already assigned to the Group' -ForegroundColor Yellow
                    }
                    ElseIf (($All -eq 'Devices') -and ($Assignment.target.'@odata.type' -eq '#microsoft.graph.allDevicesAssignmentTarget')) {
                        Write-Host 'The App is already assigned to the All Devices Group' -ForegroundColor Yellow
                    }
                    ElseIf (($All -eq 'Users') -and ($Assignment.target.'@odata.type' -eq '#microsoft.graph.allLicensedUsersAssignmentTarget')) {
                        Write-Host 'The App is already assigned to the All Users Group' -ForegroundColor Yellow
                    }
                    Else {
                        $TargetGroup = New-Object -TypeName psobject

                        if (($Assignment.target).'@odata.type' -eq '#microsoft.graph.groupAssignmentTarget') {
                            $TargetGroup | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.groupAssignmentTarget'
                            $TargetGroup | Add-Member -MemberType NoteProperty -Name 'groupId' -Value $Assignment.target.groupId
                        }

                        elseif (($Assignment.target).'@odata.type' -eq '#microsoft.graph.allLicensedUsersAssignmentTarget') {
                            $TargetGroup | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.allLicensedUsersAssignmentTarget'
                        }
                        elseif (($Assignment.target).'@odata.type' -eq '#microsoft.graph.allDevicesAssignmentTarget') {
                            $TargetGroup | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.allDevicesAssignmentTarget'
                        }

                        if ($Assignment.target.deviceAndAppManagementAssignmentFilterType -ne 'none') {

                            $TargetGroup | Add-Member -MemberType NoteProperty -Name 'deviceAndAppManagementAssignmentFilterId' -Value $Assignment.target.deviceAndAppManagementAssignmentFilterId
                            $TargetGroup | Add-Member -MemberType NoteProperty -Name 'deviceAndAppManagementAssignmentFilterType' -Value $Assignment.target.deviceAndAppManagementAssignmentFilterType
                        }

                        $Target = New-Object -TypeName psobject
                        $Target | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.mobileAppAssignment'
                        $Target | Add-Member -MemberType NoteProperty -Name 'intent' -Value $Assignment.intent
                        $Target | Add-Member -MemberType NoteProperty -Name 'target' -Value $TargetGroup
                        $TargetGroups += $Target
                    }
                }
            }
        }

        $Target = New-Object -TypeName psobject
        $Target | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.mobileAppAssignment'
        $Target | Add-Member -MemberType NoteProperty -Name 'intent' -Value $InstallIntent

        $TargetGroup = New-Object -TypeName psobject
        if ($TargetGroupId) {
            $TargetGroup | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.groupAssignmentTarget'
            $TargetGroup | Add-Member -MemberType NoteProperty -Name 'groupId' -Value $TargetGroupId
        }
        else {
            if ($All -eq 'Users') {
                $TargetGroup | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.allLicensedUsersAssignmentTarget'
            }
            ElseIf ($All -eq 'Devices') {
                $TargetGroup | Add-Member -MemberType NoteProperty -Name '@odata.type' -Value '#microsoft.graph.allDevicesAssignmentTarget'
            }
        }

        if ($FilterMode) {
            $TargetGroup | Add-Member -MemberType NoteProperty -Name 'deviceAndAppManagementAssignmentFilterId' -Value $FilterID
            $TargetGroup | Add-Member -MemberType NoteProperty -Name 'deviceAndAppManagementAssignmentFilterType' -Value $FilterMode
        }

        $Target | Add-Member -MemberType NoteProperty -Name 'target' -Value $TargetGroup
        $TargetGroups += $Target
        $Output = New-Object -TypeName psobject
        $Output | Add-Member -MemberType NoteProperty -Name 'mobileAppAssignments' -Value @($TargetGroups)

        $JSON = $Output | ConvertTo-Json -Depth 3

        $uri = "https://graph.microsoft.com/$graphApiVersion/$($Resource)"
        Invoke-MgGraphRequest -Uri $uri -Method Post -Body $JSON -ContentType 'application/json'
    }
    catch {
        Write-Error $Error[0].ErrorDetails.Message
        break
    }
}

#endregion

Do {
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

    #region Script
    Clear-Host
    $sleep = '1'
    Write-Host '************************************************************************************'
    Write-Host '****    Welcome to the Microsoft Intune App Assignment Tool                     ****' -ForegroundColor Green
    Write-Host '****    Please select the Mobile App type to Assign                             ****' -ForegroundColor Cyan
    Write-Host '************************************************************************************'
    Write-Host
    Write-Host ' Please Choose one of the options below: ' -ForegroundColor Yellow
    Write-Host
    Write-Host ' (1) Android App Assignment' -ForegroundColor Green
    Write-Host
    Write-Host ' (2) iOS App Assignment' -ForegroundColor Green
    Write-Host
    Write-Host ' (E) EXIT SCRIPT ' -ForegroundColor Red
    Write-Host
    $ChoiceA_Number = ''
    $ChoiceA_Number = Read-Host -Prompt 'Based on which App type, please type 1, 2, or E to exit the script, then press enter '
    while ( !($ChoiceA_Number -eq '1' -or $ChoiceA_Number -eq '2' -or $ChoiceA_Number -eq 'E')) {
        $ChoiceA_Number = Read-Host -Prompt 'Based on which App type, please type 1, 2, or E to exit the script, then press enter '
    }
    if ($ChoiceA_Number -eq 'E') {
        Break
    }
    if ($ChoiceA_Number -eq '1') {
        $AppType = 'android'
    }
    if ($ChoiceA_Number -eq '2') {
        $AppType = 'ios'
    }

    Write-Host 'Please select the Apps you wish to modify assigments from the pop-up' -ForegroundColor Cyan
    Start-Sleep -Seconds $sleep
    $Apps = @(Get-MobileApps | Where-Object { (!($_.'@odata.type').Contains('managed')) -and ($_.'@odata.type').contains($AppType) } | Select-Object -Property @{Label = 'App Type'; Expression = '@odata.type' }, @{Label = 'App Name'; Expression = 'displayName' }, @{Label = 'App Publisher'; Expression = 'publisher' }, @{Label = 'App ID'; Expression = 'id' } | Out-GridView -PassThru -Title 'Select Apps to Assign...')
    while ($Apps.count -eq 0) {
        $Apps = @(Get-MobileApps | Where-Object { (!($_.'@odata.type').Contains('managed')) -and ($_.'@odata.type').contains($AppType) } | Select-Object -Property @{Label = 'App Type'; Expression = '@odata.type' }, @{Label = 'App Name'; Expression = 'displayName' }, @{Label = 'App Publisher'; Expression = 'publisher' }, @{Label = 'App ID'; Expression = 'id' } | Out-GridView -PassThru -Title 'Select Apps to Assign...')
    }
    Clear-Host
    Start-Sleep -Seconds $sleep
    Write-Host '************************************************************************************'
    Write-Host '****    Welcome to the Microsoft Intune App Assignment Tool                     ****' -ForegroundColor Green
    Write-Host '****    This Script will allow bulk assignment of Apps to User and Devices      ****' -ForegroundColor Cyan
    Write-Host '************************************************************************************'
    Write-Host
    Write-Host ' Please Choose one of the options below:' -ForegroundColor Yellow
    Write-Host
    Write-Host ' (1) Replace Existing Assignments' -ForegroundColor Green
    Write-Host
    Write-Host ' (2) Add to Existing Assignments' -ForegroundColor Green
    Write-Host
    Write-Host ' (E) EXIT SCRIPT ' -ForegroundColor Red
    Write-Host
    $ChoiceB_Number = ''
    $ChoiceB_Number = Read-Host -Prompt 'Based on which Assignment Action, please type 1, 2, or E to exit the script, then press enter '
    while ( !($ChoiceB_Number -eq '1' -or $ChoiceB_Number -eq '2' -or $ChoiceB_Number -eq 'E')) {
        $ChoiceB_Number = Read-Host -Prompt 'Based on which Assignment Action, please type 1, 2, or E to exit the script, then press enter '
    }
    if ($ChoiceB_Number -eq 'E') {
        Break
    }
    if ($ChoiceB_Number -eq '1') {
        $Action = 'Replace'
    }
    if ($ChoiceB_Number -eq '2') {
        $Action = 'Add'
    }


    Clear-Host
    Start-Sleep -Seconds $sleep
    Write-Host '************************************************************************************'
    Write-Host '****    Welcome to the Microsoft Intune App Assignment Tool                     ****' -ForegroundColor Green
    Write-Host '****    Select the Assignment Group                                             ****' -ForegroundColor Cyan
    Write-Host '************************************************************************************'
    Write-Host
    Write-Host ' Please Choose one of the options below:' -ForegroundColor Yellow
    Write-Host
    Write-Host " (1) Assign Apps as 'Required'" -ForegroundColor Green
    Write-Host
    Write-Host " (2) Assign Apps as 'Available'" -ForegroundColor Green
    Write-Host
    Write-Host ' (3) Remove All Assignments' -ForegroundColor Green
    Write-Host
    Write-Host ' (E) EXIT SCRIPT ' -ForegroundColor Red
    Write-Host
    $ChoiceC_Number = ''
    $ChoiceC_Number = Read-Host -Prompt 'Based on which Install Intent type, please type 1, 2, 3 or E to exit the script, then press enter '
    while ( !($ChoiceC_Number -eq '1' -or $ChoiceC_Number -eq '2' -or $ChoiceC_Number -eq '3' -or $ChoiceC_Number -eq 'E')) {
        $ChoiceC_Number = Read-Host -Prompt 'Based on which Install Intent type, please type 1, 2, 3 or E to exit the script, then press enter '
    }
    if ($ChoiceC_Number -eq 'E') {
        Break
    }
    if ($ChoiceC_Number -eq '1') {
        $InstallIntent = 'Required'
    }
    if ($ChoiceC_Number -eq '2') {
        $InstallIntent = 'Available'
    }
    if ($ChoiceC_Number -eq '3') {
        $InstallIntent = 'Remove'
    }
    Clear-Host
    Start-Sleep -Seconds $sleep

    if ($InstallIntent -ne 'Remove') {
        Clear-Host
        Start-Sleep -Seconds $sleep
        Write-Host '************************************************************************************'
        Write-Host '****    Welcome to the Microsoft Intune App Assignment Tool                     ****' -ForegroundColor Green
        Write-Host '****    Select the Assignment Group                                             ****' -ForegroundColor Cyan
        Write-Host '************************************************************************************'
        Write-Host
        Write-Host ' Please Choose one of the options below: ' -ForegroundColor Yellow
        Write-Host
        Write-Host " (1) Assign Apps to 'All Users'" -ForegroundColor Green
        Write-Host
        Write-Host " (2) Assign Apps to 'All Devices'" -ForegroundColor Green
        Write-Host
        Write-Host ' (3) Assign Apps to a Group' -ForegroundColor Green
        Write-Host
        Write-Host ' (E) EXIT SCRIPT ' -ForegroundColor Red
        Write-Host
        $ChoiceD_Number = ''
        $ChoiceD_Number = Read-Host -Prompt 'Based on which assignment type, please type 1, 2, 3, or E to exit the script, then press enter '
        while ( !($ChoiceD_Number -eq '1' -or $ChoiceD_Number -eq '2' -or $ChoiceD_Number -eq '3' -or $ChoiceD_Number -eq 'E')) {
            $ChoiceD_Number = Read-Host -Prompt 'Based on which assignment type, please type 1, 2, 3, or E to exit the script, then press enter '
        }
        if ($ChoiceD_Number -eq 'E') {
            Break
        }
        if ($ChoiceD_Number -eq '1') {
            $AssignmentType = 'Users'
        }
        if ($ChoiceD_Number -eq '2') {
            $AssignmentType = 'Devices'
            if ($ChoiceC_Number -eq 2) {
                Write-Host "Assigning Apps as 'Available' to the 'All Devices' group will not work, please re-run the script and don't make the same mistake again..." -ForegroundColor Red
                Break
            }
        }
        if ($ChoiceD_Number -eq '3') {
            $AssignmentType = 'Group'
            if ($ChoiceC_Number -eq 2) {
                Write-Host "Assigning Apps as 'Available' to Device groups will not work, please ensure you select a group of Users" -ForegroundColor yellow
            }
            $GroupName = Read-Host 'Please enter a search term for the Assignment Group'
            While ($GroupName.Length -eq 0) {
                $GroupName = Read-Host 'Please enter a search term for the Assignment Group'
            }
            Write-Host
            Start-Sleep -Seconds $sleep
            Write-Host 'Please select the Group for the assignment...' -ForegroundColor Cyan
            Start-Sleep -Seconds $sleep
            $Group = Get-MDMGroup -GroupName $GroupName | Select-Object -Property @{Label = 'Group Name'; Expression = 'displayName' }, @{Label = 'Group ID'; Expression = 'id' } | Out-GridView -PassThru -Title 'Select Group...'

            while ($Group.Count -gt 1) {
                Write-Host 'Please select only one Group...' -ForegroundColor Yellow
                $Group = Get-MDMGroup -GroupName $GroupName | Select-Object -Property @{Label = 'Group Name'; Expression = 'displayName' }, @{Label = 'Group ID'; Expression = 'id' } | Out-GridView -PassThru -Title 'Select Group...'
            }
        }
        Clear-Host
        Start-Sleep -Seconds $sleep
        Write-Host '************************************************************************************'
        Write-Host '****    Welcome to the Microsoft Intune App Assignment Tool                     ****' -ForegroundColor Green
        Write-Host '****    Select the Device Filter                                                ****' -ForegroundColor Cyan
        Write-Host '************************************************************************************'
        Write-Host
        Write-Host ' Please Choose one of the options below: ' -ForegroundColor Yellow
        Write-Host
        Write-Host ' (1) Include Device Filter' -ForegroundColor Green
        Write-Host
        Write-Host ' (2) Exclude Device Filter' -ForegroundColor Green
        Write-Host
        Write-Host ' (3) No Filters' -ForegroundColor Green
        Write-Host
        Write-Host ' (E) EXIT SCRIPT ' -ForegroundColor Red
        Write-Host
        $ChoiceE_Number = ''
        $ChoiceE_Number = Read-Host -Prompt 'Based on which Device Filter, please type 1, 2, 3, or E to exit the script, then press enter'
        while ( !($ChoiceE_Number -eq '1' -or $ChoiceE_Number -eq '2' -or $ChoiceE_Number -eq '3' -or $ChoiceE_Number -eq 'E')) {
            $ChoiceE_Number = Read-Host -Prompt 'Based on which Device Filter, please type 1, 2, 3, or E to exit the script, then press enter'
        }
        if ($ChoiceE_Number -eq 'E') {
            Break
        }
        if ($ChoiceE_Number -eq '1') {
            $Filtering = 'Yes'
            $FilterMode = 'Include'
        }
        if ($ChoiceE_Number -eq '2') {
            $Filtering = 'Yes'
            $FilterMode = 'Exclude'
        }
        if ($ChoiceE_Number -eq '3') {
            $Filtering = 'No'
        }
        Start-Sleep -Seconds $sleep
        If ($Filtering -eq 'Yes') {
            Write-Host 'Please select the Device Filter for the assignment...' -ForegroundColor Cyan
            Start-Sleep -Seconds $sleep
            $Filter = Get-DeviceFilter | Where-Object { ($_.platform) -like ("*$AppType*") } | Select-Object -Property @{Label = 'Filter Name'; Expression = 'displayName' }, @{Label = 'Filter Rule'; Expression = 'rule' }, @{Label = 'Filter ID'; Expression = 'id' } | Out-GridView -PassThru -Title 'Select Device Filter...'

            while ($Filter.Count -gt 1) {
                Write-Host 'Please select only one Device Filter...' -ForegroundColor Yellow
                $Filter = Get-DeviceFilter | Where-Object { ($_.platform) -like ("*$AppType*") } | Select-Object -Property @{Label = 'Filter Name'; Expression = 'displayName' }, @{Label = 'Filter Rule'; Expression = 'rule' }, @{Label = 'Filter ID'; Expression = 'id' } | Out-GridView -PassThru -Title 'Select Device Filter...'
            }
        }
    }
    Clear-Host
    Start-Sleep -Seconds $sleep
    Write-Host 'The following Apps have been selected:' -ForegroundColor Cyan
    $($Apps.'App Name') | Format-List
    Write-Host
    If ($InstallIntent -ne 'Remove') {
        Write-Host 'The following Assignment Action has been selected:' -ForegroundColor Cyan
        Write-Host "$Action"
        Write-Host
        Write-Host 'The following Assignment Group has been selected:' -ForegroundColor Cyan
        if ($AssignmentType -eq 'Group') {
            Write-Host "$($Group.'Group Name')"
        }
        Else {
            Write-Host "All $AssignmentType"
        }
        Write-Host
        if ($Filtering -eq 'Yes') {
            Write-Host 'The following Device Filter has been selected:' -ForegroundColor Cyan
            Write-Host "$($Filter.'Filter Name')"
        }
    }
    Else {
        Write-Host 'Assignments will be removed.' -ForegroundColor Red
    }

    Write-Host
    Write-Warning 'Please confirm these settings are correct before continuing' -WarningAction Inquire
    Clear-Host
    Start-Sleep -Seconds $sleep

    If ($InstallIntent -ne 'Remove') {
        If ($AssignmentType -eq 'Group') {
            If ($Filtering -eq 'Yes') {
                foreach ($App in $Apps) {
                    Add-ApplicationAssignment -Id $App.'App ID' -InstallIntent $InstallIntent -TargetGroupId $Group.'Group ID' -FilterMode $FilterMode -FilterID $Filter.'Filter ID' -Action $Action
                    Write-Host "Successfully Assigned App: $($App.'App Name') as $InstallIntent to Group $($Group.'Group Name') with Filter $($Filter.'Filter Name')" -ForegroundColor Green
                }
            }
            Else {
                foreach ($App in $Apps) {
                    Add-ApplicationAssignment -Id $App.'App ID' -InstallIntent $InstallIntent -TargetGroupId $Group.'Group ID' -Action $Action
                    Write-Host "Successfully Assigned App: $($App.'App Name') as $InstallIntent to Group $($Group.'Group Name')" -ForegroundColor Green
                }
            }
        }
        Else {
            If ($Filtering -eq 'Yes') {
                foreach ($App in $Apps) {
                    Add-ApplicationAssignment -Id $App.'App ID' -InstallIntent $InstallIntent -All $AssignmentType -FilterMode $FilterMode -FilterID $Filter.'Filter ID' -Action $Action
                    Write-Host "Successfully Assigned App $($App.'App Name') as $InstallIntent to All $AssignmentType with Filter $($Filter.'Filter Name')" -ForegroundColor Green
                }
            }
            Else {
                foreach ($App in $Apps) {
                    Add-ApplicationAssignment -Id $App.'App ID' -InstallIntent $InstallIntent -All $AssignmentType -Action $Action
                    Write-Host "Successfully Assigned App $($App.'App Name') as $InstallIntent to All $AssignmentType" -ForegroundColor Green
                }
            }
        }
    }
    Else {
        Foreach ($App in $Apps) {
            $Assignments = (Get-ApplicationAssignment -Id $App.'App ID').assignments
            foreach ($Assignment in $Assignments) {
                Try {
                    Remove-ApplicationAssignment -Id $App.'App ID' -AssignmentId $Assignment.id
                    Write-Host "Successfully removed App Assignment from $($App.'App Name')" -ForegroundColor Green
                }
                Catch {
                    Write-Host "Unable to remove App Assignment from $($App.'App Name')" -ForegroundColor Red
                }

            }
        }
    }
    #endregion Script

    # Script Relaunch
    Write-Host
    Write-Host 'All Assignment Settings Complete' -ForegroundColor Green
    Write-Host
    $Title = 'Relaunch the Script'
    $Question = 'Do you want to relaunch the Script?'

    $Choices = New-Object Collections.ObjectModel.Collection[Management.Automation.Host.ChoiceDescription]
    $Choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&Yes'))
    $Choices.Add((New-Object Management.Automation.Host.ChoiceDescription -ArgumentList '&No'))

    $Decision = $Host.UI.PromptForChoice($Title, $Question, $Choices, 1)



}
until ($Decision -eq 1)
