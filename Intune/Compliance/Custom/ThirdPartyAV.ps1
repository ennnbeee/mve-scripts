$AVClient = 'Sophos Anti-Virus'
$AVProduct = Get-WmiObject -Namespace 'root\SecurityCenter2' -Class AntiVirusProduct | Where-Object { $_.displayName -eq $AVClient } | Select-Object -First 1
$AVSummary = New-Object -TypeName PSObject

If ($AVProduct) {
    $hexProductState = [Convert]::ToString($AVProduct.productState, 16).PadLeft(6, '0')
    $hexRealTimeProtection = $hexProductState.Substring(2, 2)
    $hexDefinitionStatus = $hexProductState.Substring(4, 2)

    $RealTimeProtectionStatus = switch ($hexRealTimeProtection) {
        '00' { 'Off' }
        '01' { 'Expired' }
        '10' { 'On' }
        '11' { 'Snoozed' }
        default { 'Unknown' }
    }

    $DefinitionStatus = switch ($hexDefinitionStatus) {
        '00' { 'Up to Date' }
        '10' { 'Out of Date' }
        default { 'Unknown' }
    }

    $AVSummary | Add-Member -MemberType NoteProperty -Name "$AVClient" -Value $AVProduct.displayName
    $AVSummary | Add-Member -MemberType NoteProperty -Name "$AVClient real time protection enabled" -Value $RealTimeProtectionStatus
    $AVSummary | Add-Member -MemberType NoteProperty -Name "$AVClient definitions up-to-date" -Value $DefinitionStatus
}
Else {
    $AVSummary | Add-Member -MemberType NoteProperty -Name "$AVClient" -Value 'Error: No Antivirus product found'
    $AVSummary | Add-Member -MemberType NoteProperty -Name "$AVClient real time protection enabled" -Value 'Error: No Antivirus product found'
    $AVSummary | Add-Member -MemberType NoteProperty -Name "$AVClient definitions up-to-date" -Value 'Error: No Antivirus product found'
}

return $AVSummary | ConvertTo-Json -Compress
