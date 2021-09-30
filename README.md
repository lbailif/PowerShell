# PowerShell
My PowerShell scripts

PasswordSprayDetection.ps1
- Designed to be ran as a periodic script and will send an email when password spraying is detected in an active directory environment.

AzureADGetPasswordsInComments
- Connects to Azure AD and searches user account attributes for the string 'password'

ADGetPasswordsInProperties
- Connects to on-prem AD and searches user account attributes for the string 'password'

DisableNetBiosOverTcpIp.ps1
- Disables NBNS by changing the setting on each active NIC that the script identifies.  Recommend running on a regular schedule in SCCM to pick up on any new NICs added to systems.
