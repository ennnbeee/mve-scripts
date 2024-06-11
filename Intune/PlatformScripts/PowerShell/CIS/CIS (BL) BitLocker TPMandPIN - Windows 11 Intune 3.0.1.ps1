Try {
    $osVolume = Get-BitLockerVolume | Where-Object { $_.VolumeType -eq 'OperatingSystem' }
    if ($osVolume.VolumeStatus -eq 'FullyDecrypted') {

        if ($osVolume.KeyProtector.KeyProtectorType -contains 'TpmPin') {
            $osVolume.KeyProtector | Where-Object { $_.KeyProtectorType -eq 'TpmPin' } | ForEach-Object {
                Remove-BitLockerKeyProtector -MountPoint $osVolume.MountPoint -KeyProtectorId $_.KeyProtectorId
            }
        }

        $deviceSerial = (((Get-WmiObject -Class win32_bios).Serialnumber).ToUpper() -replace '[^a-zA-Z0-9]', '')
        # Upper Case letters, removes spaces and special characters
        If ($deviceSerial.length -gt 14) {
            $deviceSerial = $deviceSerial.Substring(0, 14) # Reduce to 14 characters if longer
        }

        $devicePIN = ConvertTo-SecureString $deviceSerial -AsPlainText -Force
        Enable-BitLocker -MountPoint $osVolume.MountPoint -Pin $devicePIN -TpmAndPinProtector -ErrorAction SilentlyContinue | Out-Null
        ((Get-BitLockerVolume).KeyProtector | Where-Object { $_.KeyProtectorType -eq 'RecoveryPassword' }).KeyProtectorId | ForEach-Object {
            BackupToAAD-BitLockerKeyProtector -MountPoint $osVolume.MountPoint -KeyProtectorId $_
        }
        Exit 0
    }
    else {
        Write-Output 'Device Encrypted.'
        Exit 0
    }
}
Catch {
    $ErrorMessage = $_.Exception.Message
    Write-Warning $ErrorMessage
    Exit 1
}