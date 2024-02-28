$domain = 'ennbee.local'
$waittime = '60'

Try {

    $dcInfo = [ADSI]"LDAP://$domain"
    if ($null -eq $dcInfo.Path) {
        Write-Error "No connectivity to $domain"
    }

    $Serial = Get-WmiObject Win32_bios | Select-Object -ExpandProperty SerialNumber
    If (Get-WmiObject -Class win32_battery) {
        $newName = 'L-' + $Serial
    }
    Else {
        $newName = 'D-' + $Serial
    }

    $newName = $newName.Replace(' ', '')
    if ($newName.Length -ge 15) {
        $newName = $newName.substring(0, 15)
    }

    Rename-Computer -NewName $newName
    $waitinseconds = (New-TimeSpan -Minutes $waittime).TotalSeconds
    Write-Host "Initiating a restart in $waitime minutes"
    & shutdown.exe /g /t $waitinseconds /f /c 'Restarting the computer in 60 minutes due to a computer name change. Please save your work.'
    Write-Output "Computer renamed from $($Details.CsName) to $newName"
}
Catch {
    Write-Error $_.Exception
    Exit 2000
}