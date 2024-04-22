[CmdletBinding()]
param(

    [Parameter(Mandatory = $false)]
    [switch]$PKI,

    [Parameter(Mandatory = $true)]
    [String]$ccmSiteCode,

    [Parameter(Mandatory = $true)]
    [String]$ccmMP,

    [Parameter(Mandatory = $true)]
    [String]$cmgAddress,

    [Parameter(Mandatory = $false)]
    [String]$tenantId,

    [Parameter(Mandatory = $false)]
    [String]$clientAppId,

    [Parameter(Mandatory = $false)]
    [String]$clientAppURL

)

try {

    if ($PKI) {

        $arguments = "/forceinstall /NoCRLCheck /UsePKICert /mp:$('https://' + $cmgAddress) CCMHOSTNAME=$($cmgAddress) SMSSITECODE=$($ccmSiteCode) SMSMP=$($ccmMP)"
    }
    else {

        $arguments = "/forceinstall /mp:$('https://' + $cmgAddress) CCMHOSTNAME=$($cmgAddress) SMSSITECODE=$($ccmSiteCode) SMSMP=$($ccmMP) AADTENANTID=$($tenantId) AADCLIENTAPPID=$($clientAppId) AADRESOURCEURI=$($clientAppURL)"
    }

    Start-Process -FilePath "$PSScriptRoot\ccmsetup.exe" -PassThru -Wait -ArgumentList $arguments

    # Create a tag file just so Intune knows this was run
    $tagPath = "$($env:ProgramData)\Microsoft\CCMCMGInstall"
    While (-not (Test-Path $tagPath)) {
        mkdir $tagPath -Force
    }
    Set-Content -Path "$tagPath\Install-CCMClient.ps1.tag" -Value "Installed"
}

catch {
    $error[0]
}