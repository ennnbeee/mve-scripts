Try {
    $registry = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection'
    $path = Test-Path $registry
    $passiveMode = Get-ItemPropertyValue -Path $registry -Name ForceDefenderPassiveMode -ErrorAction SilentlyContinue

    if ($path -eq $False) {
        Write-Warning 'Defender Passive Setting Not Configured'
        Exit 1
    }
    else {
        if ($passiveMode -ne '0') {
            Write-Warning 'Defender in Passive Mode.'
            Exit 1
        }
        else {
            Write-Output 'Defender in Active Mode.'
            Exit 0
        }
    }
}
Catch {
    Write-Error $_.Exception
    Exit 2000
}

