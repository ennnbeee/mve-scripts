If ($null -eq (Get-AppxPackage -Name MicrosoftTeams -AllUsers)) {
    Write-Output 'Microsoft Teams Personal App not present'
    Exit 0
}
Else {
    Write-Output 'Microsoft Teams Personal App present' Exit 1
}