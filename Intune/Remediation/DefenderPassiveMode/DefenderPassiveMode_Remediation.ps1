Try {
    $registry = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Advanced Threat Protection'
    $path = Test-Path $registry
    $passiveMode = Get-ItemPropertyValue -Path $registry -Name ForceDefenderPassiveMode -ErrorAction SilentlyContinue

    if ($path -eq $false) {
        New-Item -Path $registry -Force | Out-Null
        New-ItemProperty -Path $registry -Name ForceDefenderPassiveMode -Value 0 -PropertyType String -Force
    }
    else {
        if ($passiveMode -ne '0') {
            New-ItemProperty -Path $Registry -Name ForceDefenderPassiveMode -Value 0 -PropertyType String -Force
        }
    }
}
Catch {
    Write-Error $_.Exception
    Exit 2000
}