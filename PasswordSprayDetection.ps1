<#
 THIS SCRIPT IS PROVIDED "AS IS" WITH NO WARRANTIES OR GUARANTEES OF ANY
 KIND, INCLUDING BUT NOT LIMITED TO MERCHANTABILITY AND/OR FITNESS FOR A
 PARTICULAR PURPOSE. ALL RISKS OF DAMAGE REMAINS WITH THE USER, EVEN IF THE
 AUTHOR, SUPPLIER OR DISTRIBUTOR HAS BEEN ADVISED OF THE POSSIBILITY OF ANY
 SUCH DAMAGE. IF YOUR STATE DOES NOT PERMIT THE COMPLETE LIMITATION OF
 LIABILITY, THEN DO NOT DOWNLOAD OR USE THE SCRIPT. NO TECHNICAL SUPPORT
 WILL BE PROVIDED.

 Description: The script will query active directory domain controllers for the lastbadpasswordattempts attribute and attempt to discover password spraying.
   The detection is based on the TimeSlice and Threshold parameters.  So, the script will generate the output file or email only if the threshold is met within the timeslice.
   This script can be ran as a scheduled tasks with email as the notification when a threshold is met.

 Requirements: 
 1. Connectivity to DCs (LDAP ports; I've also seen Active Directory Web Services port TCP/9389 for Get-ADUser) and ICMP. 
 2. The active directory module for powershell.  
 3. Read permissions on user objects in the domain.

 Examples:
 
 Get failed attempts in 1 minute from the test.com DCs and set a threshold of 20 failed attempts in 1 min.  Set output file to C:\test\spraydetection.csv.
 .\PasswordSprayDetection.ps1 -Threshold 20 -domain 'test.com' -OutFile 'C:\test\spraydection.csv'

 Use defaults. If threshold is met, send notification email with the email parameters (SMTPServer, From, To, Subject, UserName, and Password)
 .\PasswordSprayDetection.ps1 -SMTPServer "test123.test.com" -From "Me@test.com" -To "You@test.com" -Subject "Good Subject Name" -userName "SMTPUser" -Password "SuperSecretPassword"

 .\PasswordSprayDetection.ps1 -History 5 -Threshold 100 -TimeSlice "h"

 paramaters:
 Threshold - Sets the threshold for failed login attempts to alert on.  If threshold is not met, the output file will not be created.
             Default is 10.

 History - How many days back should we query for.  This is used to filter the get-aduser query to limit the results.  
           Default is 1 day, which will query today's date and yesterday's date.

 domain - Defines the domain(s) to query.  use a csv list. 
          Default will query the forest for all domains and query each domain controller in each domain. 
	      Threshold is based on single domain, but multiple domain controllers.

 OutFile - The full path and name of the output file. If the threshold is met this file is written will all timeslices and results for the domain.
           Regardless of the filename, the output will be a csv file. That is currently the only format allowed.
           Default is the current date to the second, ending with "-Spray.csv"

 TimeSlice - The unit to measure the threshold against.  Currently limited to "h" for hour and "m" for minute.  
             This will count the threshold by 1 minute timeslices or by 1 hour timeslices.
             The default is 1 minute.
 
 EMAIL PARAMETERS
  The script can be configured to send an alert email if the threshold is met.  The email includes the outfile as an attachment. 
  This may be useful if setting up a recurring scheduled task.  

 SMTPServer - The SMTP server to use for sending an alert email.
 From - The address the alert email should appear to come from.
 To - The destination mailbox for the alert email.
 Subject - The Subject of the alert email.

 EMAIL credentials
  UserName - Username used to authenticate to the SMTP server
  Password - Password used to authenticate to the SMTP server

#>
[CmdletBinding(DefaultParameterSetName='None')]
param (
#[Parameter(ParameterSetName="set1")]
# Set the default Threshold value to alert when value goes over threshold
[int] $Threshold='10',

# Set the default History variable to define how far back your query will search for
[int] $History='1',

# Set the name of the domain to search, default is to pull the list of domains from the forest
[array] $domain = (get-adforest).domains,

# Set the default output file directory and name
[string] $OutFile=(get-date -Format "yyyy-MMM-dd-mm-ss") + "-Spray.csv",

# Set the default timeslice of 1 minute.  This is used in conjunction with the threshold and defines the period of time in which to count the lastbadpasswordattempts
[ValidateSet("m", "h")]
[string] $TimeSlice = "m",

#Configure Email parameters
[Parameter(ParameterSetName="EMail")]
[string] $SMTPServer,
[Parameter(ParameterSetName="EMail",  Mandatory=$true)]
[string] $From,
[Parameter(ParameterSetName="EMail",  Mandatory=$true)]
[string] $To,
[Parameter(ParameterSetName="EMail",  Mandatory=$true)]
[string] $Subject,

# Define clear text string for username and password
[Parameter(ParameterSetName="EMail",  Mandatory=$true)]
[string]$userName,
[Parameter(ParameterSetName="EMail",  Mandatory=$true)]
[string]$Password
)

# import required module activedirectory
import-module activedirectory

# Set date for search.  This defines how far back to pull failed login dates for.  To go back farther change the -1 to a larger number
$date=(get-date).AddDays(-$History).ToString("MM/dd/yyyy")

# For each domain in the forest loop
foreach($fqdn in $domain)
{
# get list of DCs and assign to variable
$DCs = Get-ADDomainController -Filter * -Server $fqdn
# Loop through each DC to request lastbadpasswordattempt
$list = foreach ($Server in $DCs){
    If (Test-Connection -BufferSize 32 -Count 1 -ComputerName $Server.Name -Quiet) {
        write-host "Querying " $Server.Name
        Get-ADUser -Filter {lastbadpasswordattempt -gt $date} -Properties name,lastbadpasswordattempt,badpwdcount -Server $Server.Name | select name,lastbadpasswordattempt,badpwdcount,{$Server.Name}
    }
    Else {write-host "Skipping Server, Unable to connect to: " $Server.Name}
    }
}

# Sort the list by lastbadpassword
$ListSorted = $list | Sort-Object -Property lastbadpasswordattempt,name

# Initialize the $count HashTable (associative array)
$count=@{} 
# Add a count for each lastbadpasswordattempt per each minute. The result is a count for each minute in the list.
$ListSorted | ForEach-Object  { 
    $_.GetType().lastbadpasswordattempt
    #If timeslice is 1 minute, set datetime format for minutes
    If ($TimeSlice -eq "m"){
        $DateTime = $_.lastbadpasswordattempt.ToString("MM/dd hh:mm")
    }
    #elseif timeslice is 1 hour, set datetime format for hours
    ElseIf ($TimeSlice -eq "h") {
        $DateTime = $_.lastbadpasswordattempt.ToString("MM/dd hh")
    }
    $count[$DateTime]++
}

$TimeCount = $count.GetEnumerator() | sort value -Descending 

#region   If any certificates corresponds to treshold criteria create and email report...
if ($TimeCount[0].Value -gt $Threshold -and $SMTPServer -ne $null -and $SMTPServer -ne "") {
    $ListSorted | Export-Csv $OutFile

    $SMTPMessage = @{
        To = $To
        From = $From
        Subject = $Subject
        SmtpServer = $SMTPServer
        Attachments = $OutFile
    }

    # Convert to SecureString and set credential object
    [securestring]$secStringPassword = ConvertTo-SecureString $Password -AsPlainText -Force
    [pscredential]$credObject = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)

    $Body = @()
    $Body += "Hello,"
    $Body += ""
    $Body += "The number of active directory failed logins in one timeslot exceeded the threshold of $Threshold."
    $Body += ""
    $Body += "Affected Domain: $domain"
    $Body += ""
    $Body += "This may be indicative of a password spraying attempt against active directory.  Please review the attached information and investigate."
    $Body += "ATT&CK Techniques T1110 and T1110.003."
    $Body += "Review the failed logins for the time period on Domain Controller logs to correlate the source of the failed logins."
    $Body += "Query for Event IDs 4625 and 4771 events with failure code=0x18"
    $Body += ""
    $Body += "The top 5 most failed passwords is listed below."
    $Body += $TimeCount[0]
    $Body += $TimeCount[1]
    $Body += $TimeCount[2]
    $Body += $TimeCount[3]
    $Body += $TimeCount[4]
    $Body += ""
    $Body += "Happy Hunting!"
    $Body = $Body | Out-String
    
    Send-MailMessage @SMTPMessage -Body $Body -Priority High -Credential $CredObject -UseSsl
	Write-Host $Body
    
    #Cleanup Output File
    Remove-Item $OutFile

} Elseif ($TimeCount[0].Value -gt $Threshold -and ($SMTPServer -eq $null -or $SMTPServer -eq "")) {
    $ListSorted | Export-Csv $OutFile
    Write-Host "Threshold met.  The top 5 timeslices with the most failed passwords is below."
    Write-Host "Please review the output file at: " $OutFile
    Write-Host $TimeCount[0].Key $TimeCount[0].Value
    Write-Host $TimeCount[1].Key $TimeCount[1].Value
    Write-Host $TimeCount[2].Key $TimeCount[2].Value
    Write-Host $TimeCount[3].Key $TimeCount[3].Value
    Write-Host $TimeCount[4].Key $TimeCount[4].Value
    Write-Host "This may be indicative of a password spraying attempt against active directory."
    Write-Host "ATT&CK Techniques T1110 and T1110.003."
    Write-Host "Review the failed logins for the time period on Domain Controller logs to correlate the source of the failed logins."
    Write-Host "Query for Event IDs 4625 and 4771 events with failure code=0x18"
} Else {write-host "Password spraying threshold was not met."}
