$appName = 'OutlookForWindows'
if ($null -eq (Get-AppxPackage -Name $appName -AllUsers)) {
    Write-Output "$appName not installed"
    Exit 0
}
else {
    try {
        Write-Output "Removing $appName"
        Get-AppxPackage -Name $appName -AllUsers | Remove-AppPackage -AllUsers
        Write-Output "$appName removed successfully"
    }
    catch {
        Write-Error "Error removing $appName"
        Exit 2000
    }
}