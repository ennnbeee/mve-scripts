Try {
    $Details = Get-ComputerInfo
    if (-not $Details.CsPartOfDomain) {
        Write-Output 'Not Domain Joined'
        Exit 0
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

    If ($Details.CsName -ne $newName) {
        Write-Warning "Existing Computer name $($Details.CsName) should be $newName"
        Exit 1
    }
    Else {
        Write-Output "Computer has correct name: $($Details.CsName)"
        Exit 0
    }
}
Catch {
    Write-Error $_.Exception
    Exit 1
}

