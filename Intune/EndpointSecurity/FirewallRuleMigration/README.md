# Firewall Rule Migration Script

Updated version of the [Microsoft tool](https://learn.microsoft.com/en-us/mem/intune/protect/endpoint-security-firewall-rule-tool), with the following changes:

- Removed the reliance on the github repo.
- Changed to the `Microsoft.Graph` PowerShell module.
- Changed to `Invoke-MgGraphRequest` for calls to Graph.
- Force using Endpoint Security templates for firewall rule policies.
- Changed the Authentication approach to Graph to use `deviceCode`.
- Disabled sending of telemetry on success and failure.
- Fixed an issue when checking for profile name matching when there are no exiting firewall rule policies.

## Script Use

- Download the **FirewallRuleMigration** folder as a zip and unzip to your Windows device.
- Open PowerShell as Administrator.
- Navigate to the extracted folder, your PowerShell prompt should be in the **FirewallRuleMigration** folder.
- Run `Set-ExecutionPolicy Bypass` accepting all prompts.
- Run `./Export-FirewallRules.ps1` with the corresponding switches (`includeDisabledRules`, `includeLocalRules`) if required.
- Authenticate (device authentication) to Graph using a Global Admin account, twice*.
- Enter a profile name for the Firewall rules policy when prompted.
- Wait for rules to be uploaded.

> *The script will disconnect all existing Graph sessions, and connect twice; once to allow for consent to be provided, the following to allow the script to run following the consent request.

## Notes

Tested on the following versions of Windows and PowerShell:

- Windows 10 22H2, 5.1.19041.4291 - **Working**
- Windows 11 23H2, 5.1.22621.2506 - **Working**
- Windows 11 23H2, 7.4.2 - **Working**