#region Testing
$path = 'C:\Source\AaronLocker-main\AaronLocker\Outputs'
#endregion Testing

$encoding = 'UTF-8'
If (Test-Path -Path $path) {
    $xmlFiles = Get-ChildItem "$path\*.xml"
    if ($xmlFiles.Count -ne 0) {
        foreach ( $xmlFile in $xmlFiles ) {
            [xml]$xmlDoc = Get-Content $xmlFile
            $xmlDoc.xml = $($xmlDoc.CreateXmlDeclaration('1.0', $encoding, '')).Value
            #$xmlDoc.save($xmlFile.FullName)
            $xmlDocIntune = "$path\Intune-$($xmlFile.BaseName).xml"
            $xmlDoc.Save($xmlDocIntune)

            [xml]$xmlIntune = Get-Content $xmlDocIntune
            $ruleCollections = $xmlIntune.ChildNodes.RuleCollection
            foreach ($ruleCollection in $ruleCollections) {
                [xml]$xmlIntuneSetting = $ruleCollection.OuterXml
                if ($null -ne $($ruleCollection.Type)) {
                    $xmlDocIntuneSetting = "$path\Intune-$($ruleCollection.Type)-$($xmlFile.BaseName).xml"
                    Write-Host $xmlDocIntuneSetting
                    $xmlIntuneSetting.Save($xmlDocIntuneSetting)
                }
            }
        }
    }
    Else {
        Write-Host "Unable to find xml files in provided path $path" -ForegroundColor Yellow
        Break
    }
}
Else {
    Write-Host "Unable to access provided path $path" -ForegroundColor Yellow
    Break
}