if ($null -eq (Get-AppxPackage -Name MicrosoftTeams -AllUsers)) {
    Write-Output 'Microsoft Teams Personal App not present'
}
else {
    try {
        Write-Output 'Removing Microsoft Teams Personal App'
        if (Get-Process msteams -ErrorAction SilentlyContinue) {
            try {
                Write-Output 'Stopping Microsoft Teams Personal app process'
                Stop-Process msteams -Force Write-Output 'Stopped'
            }
            catch {
                Write-Output 'Unable to stop process, trying to remove anyway'
            }
        }
        Get-AppxPackage -Name MicrosoftTeams -AllUsers | Remove-AppPackage -AllUsers Write-Output 'Microsoft Teams Personal App removed successfully'
    }
    catch {
        Write-Error 'Error removing Microsoft Teams Personal App'
    }
}