$exclusions = @()
$exclusions += 'D:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.exe'
$exclusions += 'D:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\arm64\DISM\dism.exe'
$exclusions += 'D:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\x86\DISM\dism.exe'
$exclusions += 'D:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\wimserv.exe'
$exclusions += 'D:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\arm64\DISM\wimserv.exe'
$exclusions += 'D:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\x86\DISM\wimserv.exe'
$exclusions += 'D:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\pkgmgr.exe'
$exclusions += 'D:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\arm64\DISM\pkgmgr.exe'
$exclusions += 'D:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\x86\DISM\pkgmgr.exe'
$exclusions += 'D:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\BCDBoot\bcdedit.exe'
$exclusions += 'D:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\BCDBoot\bcdboot.exe'
$exclusions += 'D:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\arm64\BCDBoot\bcdedit.exe'
$exclusions += 'D:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\arm64\BCDBoot\bcdboot.exe'
$exclusions += 'D:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\x86\BCDBoot\bcdedit.exe'
$exclusions += 'D:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\x86\BCDBoot\bcdboot.exe'

foreach ($exclusion in $exclusions) {
    Add-MpPreference -AttackSurfaceReductionOnlyExclusions $exclusion
}