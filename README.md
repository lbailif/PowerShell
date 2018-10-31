# PowerShell
My PowerShell scripts

All_Reg_Run_Keys.ps1
This script was inspired by some work done by Jason Fossen, so, I have to give some credit to him.  I took his SANS course and created this script soon after.  I really can't remember at this point which code I directly stole and is originally his vs. what I've added.  So, special thanks to Jason and SANS Security 505.

I created this script to do some threat hunting with long tail analysis on common registry run keys.  Here's a breakdown of what the script does
- Pulls a list of windows computers from your domain  
  -  Alternatively, you may specify an OU to use by modifying the $Searcher variable
  -  example: $Searcher = New-Object DirectoryServices.DirectorySearcher([ADSI]"LDAP://OU=computers,DC=domain,DC=local")
- creates a folder on the C drive called All_Reg_Run_Keys
- It loops through the array of computers and remotely gathers all listed Run keys
  HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
  HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnceEx
  HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce
  HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options
  HKLM\SOFTWARE\Wow6432node\Microsoft\Windows\CurrentVersion\Run
  HKLM\SOFTWARE\Wow6432node\Microsoft\Windows\CurrentVersion\RunOnce
  HKU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
  HKU\SOFTWARE\Microsoft\Windows\CurrentVersion\Run
  HKU\Environment\UserInitMprLogonScript
- The keys are added to two files in the previously created folder, RegKeys.txt and UserRegKeys.txt
- Then the script processes the files to create a list of keys sorted by count of computers have that key.  These output to two files, KeyCounts.txt and UserKeyCounts.txt

RegKeys Whitelisting
You can specify a whitelist if you have some known good keys.  I included an example in the HKLM processing and a key I've come across in the HKU processing.  The idea behind the whitelists are to investigate the registry run keys, consider them good reg keys and then you won't see them on any subsequent runs.

What do I do with the files now that I've ran the script?
- investigate the files that execute based on the reg key information in the RegKeys.txt and UserRegKeys.txt.

You can look into all the files or just start with a long tail analysis approach and look at those only on a few computers.  Copy the key name from the counts file and search for it in the RegKeys or UserRegKeys file.  This will give you the details of the reg key, including the path to the process it calls and the computer it's on.  Once you've verified the file is considered Good, you can add it to the Whitelist.  Whitelist should be a "name1","name2","name3" format.
Then, you can run it again every day/week/month/etc. 


If you use this, let me know how it works for you and if there's any specific functionality you would like to see or reg keys added.
