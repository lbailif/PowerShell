###########################################################################
#
# NAME: DisableNetBiosOverTcpIp.ps1
#
# AUTHOR:  Luke Bailiff
#
# COMMENT: This script will scan through all enabled NICs and disable Netbios Over TCP/IP
#
# VERSION HISTORY:
# 1.0 2015 OCT 09 - Initial release
#
###########################################################################
$adapters=$null
$adapters=(gwmi win32_networkadapterconfiguration -Filter 'ipenabled = "true"')
Foreach ($nic in $adapters | where-object {$nic.TcpipNetbiosOptions -ne 2} ) {
$nic.SetTcpipNetbios("2")
}

#Write-EventLog -LogName Application -Source ComplianceNebiosDisabled -EntryType Information -EventID 501 -Message "NetBIOS over TCP/IP has been DISABLED by SCCM remediation script."