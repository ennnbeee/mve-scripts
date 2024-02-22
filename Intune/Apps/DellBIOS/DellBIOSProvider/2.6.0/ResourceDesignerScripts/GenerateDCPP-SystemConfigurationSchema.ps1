##########################################################################
# DELL PROPRIETARY INFORMATION
#
# This software is confidential.  Dell Inc., or one of its subsidiaries, has supplied this
# software to you under the terms of a license agreement,nondisclosure agreement or both.
# You may not copy, disclose, or use this software except in accordance with those terms.
#
# Copyright 2020 Dell Inc. or its subsidiaries.  All Rights Reserved.
#
# DELL INC. MAKES NO REPRESENTATIONS OR WARRANTIES ABOUT THE SUITABILITY OF THE SOFTWARE,
# EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, OR NON-INFRINGEMENT.
# DELL SHALL NOT BE LIABLE FOR ANY DAMAGES SUFFERED BY LICENSEE AS A RESULT OF USING,
# MODIFYING OR DISTRIBUTING THIS SOFTWARE OR ITS DERIVATIVES.
#
#
#
##########################################################################

<#
This is a Resource designer script which generates a mof schema for DCPP_POSTBehavior resource in DellBIOSProvider module.


#>

$category = New-xDscResourceProperty -name Category -Type String -Attribute Key
$integratedNIC = New-xDscResourceProperty -name IntegratedNIC -Type String -Attribute Write -ValidateSet @("Enabled", "Enabled with PXE", "Enabled with ImageServer", "Enabled with RPL Boot", "Enabled with ISCSI Boot")
$uefiNetworkStack = New-xDscResourceProperty -name UEFINetworkStack -Type String -Attribute Write -ValidateSet @("Enabled", "Disabled")
$parallelPort = New-xDscResourceProperty -name ParallelPort -Type String -Attribute Write -ValidateSet @("Disabled", "AT", "PS2", "ECP")
$serialPort1 = New-xDscResourceProperty -name SerialPort1 -Type String -Attribute Write -ValidateSet @("Disabled", "COM1", "COM2", "COM3", "COM4", "Auto")
$sataOperation = New-xDscResourceProperty -name SATAOperation -Type String -Attribute Write -ValidateSet @("Disabled", "ATA", "AHCI", "RAID On")
$sata0 = New-xDscResourceProperty -name SATA0 -Type String -Attribute Write -ValidateSet @("Enabled", "Disabled")
$sata1 = New-xDscResourceProperty -name SATA1 -Type String -Attribute Write -ValidateSet @("Enabled", "Disabled")
$sata2 = New-xDscResourceProperty -name SATA2 -Type String -Attribute Write -ValidateSet @("Enabled", "Disabled")
$sata3 = New-xDscResourceProperty -name SATA3 -Type String -Attribute Write -ValidateSet @("Enabled", "Disabled")
$smartReporting = New-xDscResourceProperty -name SMARTReporting -Type String -Attribute Write -ValidateSet @("Enabled", "Disabled")
$usbPowerShare = New-xDscResourceProperty -name USBPowerShare -Type String -Attribute Write -ValidateSet @("Enabled", "Disabled")
$audio = New-xDscResourceProperty -name Audio -Type String -Attribute Write -ValidateSet @("Enabled", "Disabled")
$keyboardIllumination = New-xDscResourceProperty -name KeyboardIllumination -Type String -Attribute Write -ValidateSet @("Enabled", "Disabled")
$keyboardBacklightwithAC = New-xDscResourceProperty -name KeyboardBacklightWithAC -Type String -Attribute Write -ValidateSet @("Enabled", "Disabled")
$Password = New-xDscResourceProperty -Name Password -Type string -Attribute Write -Description "Password"
$SecurePassword = New-xDscResourceProperty -Name SecurePassword -Type string -Attribute Write -Description "SecurePassword"
$PathToKey = New-xDscResourceProperty -Name PathToKey -Type string -Attribute Write



$properties = @($category, $integratedNIC, $uefiNetworkStack, $parallelPort, $serialPort1, $sataOperation, $sata0, $sata1, $sata2, $sata3, $smartReporting, $usbPowerShare, $audio, $keyboardIllumination, $keyboardBacklightwithAC,$Password,$SecurePassword,$PathToKey)

New-xDscResource -ModuleName DellBIOSProviderX86 -Name DCPP_SystemConfiguration -Property $properties -Path 'C:\Program Files\WindowsPowerShell\Modules' -FriendlyName "SystemConfiguration" -Force -Verbose

# SIG # Begin signature block
# MIIcOwYJKoZIhvcNAQcCoIIcLDCCHCgCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD+2fqOwQfmxNpu
# 6I3TqIEsegW3ha8hbT3Vm0Ql+fGWm6CCCsowggUyMIIEGqADAgECAg0Ah4JSYAAA
# AABR03PZMA0GCSqGSIb3DQEBCwUAMIG+MQswCQYDVQQGEwJVUzEWMBQGA1UEChMN
# RW50cnVzdCwgSW5jLjEoMCYGA1UECxMfU2VlIHd3dy5lbnRydXN0Lm5ldC9sZWdh
# bC10ZXJtczE5MDcGA1UECxMwKGMpIDIwMDkgRW50cnVzdCwgSW5jLiAtIGZvciBh
# dXRob3JpemVkIHVzZSBvbmx5MTIwMAYDVQQDEylFbnRydXN0IFJvb3QgQ2VydGlm
# aWNhdGlvbiBBdXRob3JpdHkgLSBHMjAeFw0xNTA2MTAxMzQyNDlaFw0zMDExMTAx
# NDEyNDlaMIHIMQswCQYDVQQGEwJVUzEWMBQGA1UEChMNRW50cnVzdCwgSW5jLjEo
# MCYGA1UECxMfU2VlIHd3dy5lbnRydXN0Lm5ldC9sZWdhbC10ZXJtczE5MDcGA1UE
# CxMwKGMpIDIwMTUgRW50cnVzdCwgSW5jLiAtIGZvciBhdXRob3JpemVkIHVzZSBv
# bmx5MTwwOgYDVQQDEzNFbnRydXN0IEV4dGVuZGVkIFZhbGlkYXRpb24gQ29kZSBT
# aWduaW5nIENBIC0gRVZDUzEwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDCvTcBUALFjaAu6GYnHZUIy25XB1LW0LrF3euJF8ImXC9xK37LNqRREEd4nmoZ
# NOgdYyPieuOhKrZqae5SsMpnwyjY83cwTpCAZJm/6m9nZRIi25xuAw2oUGH4WMSd
# fTrwgSX/8yoS4WvlTZVFysFX9yAtx4EUgbqYLygPSULr/C9rwM298YzqPvw/sXx9
# d7y4YmgyA7Bj8irPXErEQl+bgis4/tlGm0xfY7c0rFT7mcQBI/vJCZTjO59K4oow
# 56ScK63Cb212E4I7GHJpewOYBUpLm9St3OjXvWjuY96yz/c841SAD/sjrLUyXE5A
# PfhMspUyThqkyEbw3weHuJrvAgMBAAGjggEhMIIBHTAOBgNVHQ8BAf8EBAMCAQYw
# EwYDVR0lBAwwCgYIKwYBBQUHAwMwEgYDVR0TAQH/BAgwBgEB/wIBADAzBggrBgEF
# BQcBAQQnMCUwIwYIKwYBBQUHMAGGF2h0dHA6Ly9vY3NwLmVudHJ1c3QubmV0MDAG
# A1UdHwQpMCcwJaAjoCGGH2h0dHA6Ly9jcmwuZW50cnVzdC5uZXQvZzJjYS5jcmww
# OwYDVR0gBDQwMjAwBgRVHSAAMCgwJgYIKwYBBQUHAgEWGmh0dHA6Ly93d3cuZW50
# cnVzdC5uZXQvcnBhMB0GA1UdDgQWBBQqCm8yLCkgIXZqsayMPK+Tjg5rojAfBgNV
# HSMEGDAWgBRqciZ60B7vfec7aVHUbI2fkBJmqzANBgkqhkiG9w0BAQsFAAOCAQEA
# KdkNr2dFXRsJb63MiBD1qi4mF+2Ih6zA+B1TuRAPZTIzazJPXdYdD3h8CVS1WhKH
# X6Q2SwdH0Gdsoipgwl0I3SNgPXkqoBX09XVdIVfA8nFDB6k+YMUZA/l8ub6ARctY
# xthqVO7Or7jUjpA5E3EEXbj8h9UMLM5w7wUcdBAteXZKeFU7SOPId1AdefnWSD/n
# bqvfvZLnJyfAWLO+Q5VvpPzZNgBa+8mM9DieRiaIvILQX30SeuWbL9TEU+XBKdyQ
# +P/h8jqHo+/edtNuajulxlIwHmOrwAlA8cnC8sw41jqy2hVo/IyXdSpYCSziidmE
# CU2X7RYuZTGuuPUtJcF5dDCCBZAwggR4oAMCAQICD3HnAZHCZ4Xw8xAzN3V0njAN
# BgkqhkiG9w0BAQsFADCByDELMAkGA1UEBhMCVVMxFjAUBgNVBAoTDUVudHJ1c3Qs
# IEluYy4xKDAmBgNVBAsTH1NlZSB3d3cuZW50cnVzdC5uZXQvbGVnYWwtdGVybXMx
# OTA3BgNVBAsTMChjKSAyMDE1IEVudHJ1c3QsIEluYy4gLSBmb3IgYXV0aG9yaXpl
# ZCB1c2Ugb25seTE8MDoGA1UEAxMzRW50cnVzdCBFeHRlbmRlZCBWYWxpZGF0aW9u
# IENvZGUgU2lnbmluZyBDQSAtIEVWQ1MxMB4XDTIwMTExOTIxNTUwOFoXDTIxMTIx
# MjIxNTUwN1owgdgxCzAJBgNVBAYTAlVTMQ4wDAYDVQQIEwVUZXhhczETMBEGA1UE
# BxMKUm91bmQgUm9jazETMBEGCysGAQQBgjc8AgEDEwJVUzEZMBcGCysGAQQBgjc8
# AgECEwhEZWxhd2FyZTERMA8GA1UEChMIRGVsbCBJbmMxHTAbBgNVBA8TFFByaXZh
# dGUgT3JnYW5pemF0aW9uMR0wGwYDVQQLExRDbGllbnQgUHJvZHVjdCBHcm91cDEQ
# MA4GA1UEBRMHMjE0MTU0MTERMA8GA1UEAxMIRGVsbCBJbmMwggEiMA0GCSqGSIb3
# DQEBAQUAA4IBDwAwggEKAoIBAQCtsUxaEbdP93k7fH+aROiSPIJ+YewmCSc4fIOo
# 4QeQvzVl2V9i5dS10Vl0pguq30l4EINnHd+8tMgIKwjiKRyuSjzSGv02HhnjIj4N
# ZGAGHAHOl67N8B2Tn2xJs+obpB6S6ZVDlTep30Oaif3wFh0lRPhXwZqmkZo4wPk/
# XTAAr6EvkNsF02BluYDqFYLztXBuTb6TFx/6jXjzN8z2GcYzb2p/LbnVGWeuyyvS
# YkY0z+8QlYezGbsD/5I/aIxi/6hoDhM9t1gmfFu8byeYF0iQv9HN//+yKPpHZ9NX
# cbuFG8yZssRrDMSE+TdDaF0hhywpyDzK2tQL9x9OVaSS8gxbAgMBAAGjggFjMIIB
# XzAMBgNVHRMBAf8EAjAAMB0GA1UdDgQWBBQPbg/plOi4U1vRuFqxMH8mepZ6vDAf
# BgNVHSMEGDAWgBQqCm8yLCkgIXZqsayMPK+Tjg5rojBqBggrBgEFBQcBAQReMFww
# IwYIKwYBBQUHMAGGF2h0dHA6Ly9vY3NwLmVudHJ1c3QubmV0MDUGCCsGAQUFBzAC
# hilodHRwOi8vYWlhLmVudHJ1c3QubmV0L2V2Y3MxLWNoYWluMjU2LmNlcjAxBgNV
# HR8EKjAoMCagJKAihiBodHRwOi8vY3JsLmVudHJ1c3QubmV0L2V2Y3MxLmNybDAO
# BgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwSwYDVR0gBEQwQjA3
# BgpghkgBhvpsCgECMCkwJwYIKwYBBQUHAgEWG2h0dHBzOi8vd3d3LmVudHJ1c3Qu
# bmV0L3JwYTAHBgVngQwBAzANBgkqhkiG9w0BAQsFAAOCAQEAiF7xd3GBxaI9u4RZ
# CEbblLpwzGcmBLvR0fiwgTASbadHYmOTPOYR3PsPsM5tQyLcdei9zser2TsHYNfk
# fmPXXA3C3TtUDzK6jKskniivaTa0DD51rKjiDGCJCaL6PuiaoM7koTmM2vJ+3miP
# rhqZF4dN9oB4/I7qKBCBHAr08VdD7nTP4lkSR54Bgim8I3mS4iEK2EPtRJzKDyqr
# jDlCyRY3EWocFqpnU4qoiMhUwK1CUNvqtTcQOzXhWSjHqPvfQlDINo6GrWadnByT
# yPrcgrfrIwrXkLxj99tvknAB17fFS1Xyku+PkevhkoOpdAWKogXOjrNwuO2etQou
# 8Pl8ODGCEMcwghDDAgEBMIHcMIHIMQswCQYDVQQGEwJVUzEWMBQGA1UEChMNRW50
# cnVzdCwgSW5jLjEoMCYGA1UECxMfU2VlIHd3dy5lbnRydXN0Lm5ldC9sZWdhbC10
# ZXJtczE5MDcGA1UECxMwKGMpIDIwMTUgRW50cnVzdCwgSW5jLiAtIGZvciBhdXRo
# b3JpemVkIHVzZSBvbmx5MTwwOgYDVQQDEzNFbnRydXN0IEV4dGVuZGVkIFZhbGlk
# YXRpb24gQ29kZSBTaWduaW5nIENBIC0gRVZDUzECD3HnAZHCZ4Xw8xAzN3V0njAN
# BglghkgBZQMEAgEFAKB8MBAGCisGAQQBgjcCAQwxAjAAMBkGCSqGSIb3DQEJAzEM
# BgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMC8GCSqG
# SIb3DQEJBDEiBCAdajuVy0q09H2WmAAM4RnTNKkU4kBN2UKTd040VBXsKjANBgkq
# hkiG9w0BAQEFAASCAQAUqdw7zL2H3EVyVq2791EEKgt7j3KQi1znoZnuyH7vucrn
# iqb4eNeTtwRnWwaru8zmhfQhbBQc6F+uRULgviM/Ax63aGbxopdWTT759ammmfE3
# NTH2nOuU28diCHsiDgfa2pxGVCd5M5wdoG9eKbaIhQk6rx2e2STEP+64FDQssJNx
# rU9B9ma5TRWjtPRuRg8Bs1UYFdE6cas/R0U3VuTd+rQRg4jE6osNv+htpVIFs2Tf
# n7vdfVjjEWjIDNO406pd9/mRtSbYOq5BgKZjO+zsfbFgl0CO1Cw/c/ke9oG1Tfky
# SUM8o9RxNG+EeOw+JgTll6GJz4p06gfTBM2QT/dpoYIOPTCCDjkGCisGAQQBgjcD
# AwExgg4pMIIOJQYJKoZIhvcNAQcCoIIOFjCCDhICAQMxDTALBglghkgBZQMEAgEw
# ggEPBgsqhkiG9w0BCRABBKCB/wSB/DCB+QIBAQYLYIZIAYb4RQEHFwMwMTANBglg
# hkgBZQMEAgEFAAQgiRNXZufH5y95gFkx8MG+VAuOg+kqhFLx0clH3j8t9HoCFQDy
# MhpVhtDIRpBN7EZGunXL3iKV9xgPMjAyMTA5MDIxMTU0NTJaMAMCAR6ggYakgYMw
# gYAxCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3JhdGlvbjEf
# MB0GA1UECxMWU3ltYW50ZWMgVHJ1c3QgTmV0d29yazExMC8GA1UEAxMoU3ltYW50
# ZWMgU0hBMjU2IFRpbWVTdGFtcGluZyBTaWduZXIgLSBHM6CCCoswggU4MIIEIKAD
# AgECAhB7BbHUSWhRRPfJidKcGZ0SMA0GCSqGSIb3DQEBCwUAMIG9MQswCQYDVQQG
# EwJVUzEXMBUGA1UEChMOVmVyaVNpZ24sIEluYy4xHzAdBgNVBAsTFlZlcmlTaWdu
# IFRydXN0IE5ldHdvcmsxOjA4BgNVBAsTMShjKSAyMDA4IFZlcmlTaWduLCBJbmMu
# IC0gRm9yIGF1dGhvcml6ZWQgdXNlIG9ubHkxODA2BgNVBAMTL1ZlcmlTaWduIFVu
# aXZlcnNhbCBSb290IENlcnRpZmljYXRpb24gQXV0aG9yaXR5MB4XDTE2MDExMjAw
# MDAwMFoXDTMxMDExMTIzNTk1OVowdzELMAkGA1UEBhMCVVMxHTAbBgNVBAoTFFN5
# bWFudGVjIENvcnBvcmF0aW9uMR8wHQYDVQQLExZTeW1hbnRlYyBUcnVzdCBOZXR3
# b3JrMSgwJgYDVQQDEx9TeW1hbnRlYyBTSEEyNTYgVGltZVN0YW1waW5nIENBMIIB
# IjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAu1mdWVVPnYxyXRqBoutV87AB
# rTxxrDKPBWuGmicAMpdqTclkFEspu8LZKbku7GOz4c8/C1aQ+GIbfuumB+Lef15t
# QDjUkQbnQXx5HMvLrRu/2JWR8/DubPitljkuf8EnuHg5xYSl7e2vh47Ojcdt6tKY
# tTofHjmdw/SaqPSE4cTRfHHGBim0P+SDDSbDewg+TfkKtzNJ/8o71PWym0vhiJka
# 9cDpMxTW38eA25Hu/rySV3J39M2ozP4J9ZM3vpWIasXc9LFL1M7oCZFftYR5NYp4
# rBkyjyPBMkEbWQ6pPrHM+dYr77fY5NUdbRE6kvaTyZzjSO67Uw7UNpeGeMWhNwID
# AQABo4IBdzCCAXMwDgYDVR0PAQH/BAQDAgEGMBIGA1UdEwEB/wQIMAYBAf8CAQAw
# ZgYDVR0gBF8wXTBbBgtghkgBhvhFAQcXAzBMMCMGCCsGAQUFBwIBFhdodHRwczov
# L2Quc3ltY2IuY29tL2NwczAlBggrBgEFBQcCAjAZGhdodHRwczovL2Quc3ltY2Iu
# Y29tL3JwYTAuBggrBgEFBQcBAQQiMCAwHgYIKwYBBQUHMAGGEmh0dHA6Ly9zLnN5
# bWNkLmNvbTA2BgNVHR8ELzAtMCugKaAnhiVodHRwOi8vcy5zeW1jYi5jb20vdW5p
# dmVyc2FsLXJvb3QuY3JsMBMGA1UdJQQMMAoGCCsGAQUFBwMIMCgGA1UdEQQhMB+k
# HTAbMRkwFwYDVQQDExBUaW1lU3RhbXAtMjA0OC0zMB0GA1UdDgQWBBSvY9bKo06F
# cuCnvEHzKaI4f4B1YjAfBgNVHSMEGDAWgBS2d/ppSEefUxLVwuoHMnYH0ZcHGTAN
# BgkqhkiG9w0BAQsFAAOCAQEAdeqwLdU0GVwyRf4O4dRPpnjBb9fq3dxP86HIgYj3
# p48V5kApreZd9KLZVmSEcTAq3R5hF2YgVgaYGY1dcfL4l7wJ/RyRR8ni6I0D+8yQ
# L9YKbE4z7Na0k8hMkGNIOUAhxN3WbomYPLWYl+ipBrcJyY9TV0GQL+EeTU7cyhB4
# bEJu8LbF+GFcUvVO9muN90p6vvPN/QPX2fYDqA/jU/cKdezGdS6qZoUEmbf4Blfh
# xg726K/a7JsYH6q54zoAv86KlMsB257HOLsPUqvR45QDYApNoP4nbRQy/D+XQOG/
# mYnb5DkUvdrk08PqK1qzlVhVBH3HmuwjA42FKtL/rqlhgTCCBUswggQzoAMCAQIC
# EHvU5a+6zAc/oQEjBCJBTRIwDQYJKoZIhvcNAQELBQAwdzELMAkGA1UEBhMCVVMx
# HTAbBgNVBAoTFFN5bWFudGVjIENvcnBvcmF0aW9uMR8wHQYDVQQLExZTeW1hbnRl
# YyBUcnVzdCBOZXR3b3JrMSgwJgYDVQQDEx9TeW1hbnRlYyBTSEEyNTYgVGltZVN0
# YW1waW5nIENBMB4XDTE3MTIyMzAwMDAwMFoXDTI5MDMyMjIzNTk1OVowgYAxCzAJ
# BgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRlYyBDb3Jwb3JhdGlvbjEfMB0GA1UE
# CxMWU3ltYW50ZWMgVHJ1c3QgTmV0d29yazExMC8GA1UEAxMoU3ltYW50ZWMgU0hB
# MjU2IFRpbWVTdGFtcGluZyBTaWduZXIgLSBHMzCCASIwDQYJKoZIhvcNAQEBBQAD
# ggEPADCCAQoCggEBAK8Oiqr43L9pe1QXcUcJvY08gfh0FXdnkJz93k4Cnkt29uU2
# PmXVJCBtMPndHYPpPydKM05tForkjUCNIqq+pwsb0ge2PLUaJCj4G3JRPcgJiCYI
# Ovn6QyN1R3AMs19bjwgdckhXZU2vAjxA9/TdMjiTP+UspvNZI8uA3hNN+RDJqgoY
# bFVhV9HxAizEtavybCPSnw0PGWythWJp/U6FwYpSMatb2Ml0UuNXbCK/VX9vygar
# P0q3InZl7Ow28paVgSYs/buYqgE4068lQJsJU/ApV4VYXuqFSEEhh+XetNMmsntA
# U1h5jlIxBk2UA0XEzjwD7LcA8joixbRv5e+wipsCAwEAAaOCAccwggHDMAwGA1Ud
# EwEB/wQCMAAwZgYDVR0gBF8wXTBbBgtghkgBhvhFAQcXAzBMMCMGCCsGAQUFBwIB
# FhdodHRwczovL2Quc3ltY2IuY29tL2NwczAlBggrBgEFBQcCAjAZGhdodHRwczov
# L2Quc3ltY2IuY29tL3JwYTBABgNVHR8EOTA3MDWgM6Axhi9odHRwOi8vdHMtY3Js
# LndzLnN5bWFudGVjLmNvbS9zaGEyNTYtdHNzLWNhLmNybDAWBgNVHSUBAf8EDDAK
# BggrBgEFBQcDCDAOBgNVHQ8BAf8EBAMCB4AwdwYIKwYBBQUHAQEEazBpMCoGCCsG
# AQUFBzABhh5odHRwOi8vdHMtb2NzcC53cy5zeW1hbnRlYy5jb20wOwYIKwYBBQUH
# MAKGL2h0dHA6Ly90cy1haWEud3Muc3ltYW50ZWMuY29tL3NoYTI1Ni10c3MtY2Eu
# Y2VyMCgGA1UdEQQhMB+kHTAbMRkwFwYDVQQDExBUaW1lU3RhbXAtMjA0OC02MB0G
# A1UdDgQWBBSlEwGpn4XMG24WHl87Map5NgB7HTAfBgNVHSMEGDAWgBSvY9bKo06F
# cuCnvEHzKaI4f4B1YjANBgkqhkiG9w0BAQsFAAOCAQEARp6v8LiiX6KZSM+oJ0sh
# zbK5pnJwYy/jVSl7OUZO535lBliLvFeKkg0I2BC6NiT6Cnv7O9Niv0qUFeaC24pU
# bf8o/mfPcT/mMwnZolkQ9B5K/mXM3tRr41IpdQBKK6XMy5voqU33tBdZkkHDtz+G
# 5vbAf0Q8RlwXWuOkO9VpJtUhfeGAZ35irLdOLhWa5Zwjr1sR6nGpQfkNeTipoQ3P
# tLHaPpp6xyLFdM3fRwmGxPyRJbIblumFCOjd6nRgbmClVnoNyERY3Ob5SBSe5b/e
# AL13sZgUchQk38cRLB8AP8NLFMZnHMweBqOQX1xUiz7jM1uCD8W3hgJOcZ/pZkU/
# djGCAlowggJWAgEBMIGLMHcxCzAJBgNVBAYTAlVTMR0wGwYDVQQKExRTeW1hbnRl
# YyBDb3Jwb3JhdGlvbjEfMB0GA1UECxMWU3ltYW50ZWMgVHJ1c3QgTmV0d29yazEo
# MCYGA1UEAxMfU3ltYW50ZWMgU0hBMjU2IFRpbWVTdGFtcGluZyBDQQIQe9Tlr7rM
# Bz+hASMEIkFNEjALBglghkgBZQMEAgGggaQwGgYJKoZIhvcNAQkDMQ0GCyqGSIb3
# DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yMTA5MDIxMTU0NTJaMC8GCSqGSIb3DQEJ
# BDEiBCB4Dw2dtLmY18QQZ4h+iH4wRIU+1a1FTSGtS+fXTzHtXzA3BgsqhkiG9w0B
# CRACLzEoMCYwJDAiBCDEdM52AH0COU4NpeTefBTGgPniggE8/vZT7123H99h+DAL
# BgkqhkiG9w0BAQEEggEAkD5vzcJoLNpOQMfYmwU72Nd7rkceHuesWYRvNEg8kU3y
# mr7Oddb/5qOYTAFn5vSVbkFGmvzhxBZxsQQjWWXW+80GW+uFtHJmO6Ryiuu6DqoX
# 61jP5pO+ctXMa3xexI1QVpuqXyjZaGGvApqTPTHX6ABjyxcBMZkSsZ3Ms4+wFImq
# wNhPCyL9k1noeEQrRY3ynVhvuPALWXhGcY0YhZCkpXfmmXS/czg4cKKQwEl/4VT2
# qWCY7qfH4leaZvJq5v7mbuIlNnLIhPaw+qO+i4tpSxU5dCXwAj1FjiMhQxiVzLmr
# HfmUYgz3Br2Tj2kWr6XL5h+WRFi125Xf2ufZmKagZQ==
# SIG # End signature block