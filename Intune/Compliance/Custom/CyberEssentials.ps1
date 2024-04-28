$guestAccount = Get-WmiObject Win32_UserAccount | Where-Object SID -Like '*501' | Select-Object Domain, Name, Disabled
$cyberEssentials = New-Object -TypeName PSObject

$guestAccountStatus = switch ($guestAccount.Disabled) {
    'True' { 'Disabled' }
    'False' { 'Enabled' }
}

$cyberEssentials | Add-Member -MemberType NoteProperty -Name 'Guest Account Status' -Value $guestAccountStatus

return $cyberEssentials | ConvertTo-Json -Compress