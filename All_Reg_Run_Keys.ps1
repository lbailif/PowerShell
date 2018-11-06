# THIS SCRIPT IS PROVIDED "AS IS" WITH NO WARRANTIES OR GUARANTEES OF ANY
# KIND, INCLUDING BUT NOT LIMITED TO MERCHANTABILITY AND/OR FITNESS FOR A
# PARTICULAR PURPOSE. ALL RISKS OF DAMAGE REMAINS WITH THE USER, EVEN IF THE
# AUTHOR, SUPPLIER OR DISTRIBUTOR HAS BEEN ADVISED OF THE POSSIBILITY OF ANY
# SUCH DAMAGE. IF YOUR STATE DOES NOT PERMIT THE COMPLETE LIMITATION OF
# LIABILITY, THEN DO NOT DOWNLOAD OR USE THE SCRIPT. NO TECHNICAL SUPPORT
# WILL BE PROVIDED.
#
# Get list of all windows computers from directory services and add to array
$Searcher = New-Object DirectoryServices.DirectorySearcher([ADSI]"")
$Searcher.Filter = "(&(objectClass=computer)(operatingSystem=*Windows*))"
$Computers = ($Searcher.Findall())

#create directory to place the files in.  If the folder already exist, this will fail
if((Test-Path "C:\All_Reg_RunKeys") -eq 0) {
  md C:\All_Reg_RunKeys
}

#Delete the files to start a clean run
remove-item C:\All_Reg_RunKeys\KeyCounts.txt
remove-item C:\All_Reg_RunKeys\RegKeys.txt
remove-item C:\All_Reg_RunKeys\UserKeyCounts.txt
remove-item C:\All_Reg_RunKeys\UserRegKeys.txt

#Loop through each computer name and place the reg key's into files
Foreach ($Computer in $Computers)
{
  $Path=$Computer.Path
  $Name=([ADSI]"$Path").Name
  write-host $Name
  $Name | out-file -append C:\All_Reg_RunKeys\RegKeys.txt
  $Name | out-file -append C:\All_Reg_RunKeys\UserRegKeys.txt
  
If (Test-Connection -BufferSize 32 -Count 1 -ComputerName $Name -Quiet) {
  net use \\$Name | out-null
  reg query \\$Name\HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run | out-file -append C:\All_Reg_RunKeys\RegKeys.txt
  reg query \\$Name\HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnceEx | out-file -append C:\All_Reg_RunKeys\RegKeys.txt
  reg query \\$Name\HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce | out-file -append C:\All_Reg_RunKeys\RegKeys.txt
  reg query \\$Name\HKLM\SOFTWARE\Wow6432node\Microsoft\Windows\CurrentVersion\Run | out-file -append C:\All_Reg_RunKeys\RegKeys.txt
  reg query \\$Name\HKLM\SOFTWARE\Wow6432node\Microsoft\Windows\CurrentVersion\RunOnce | out-file -append C:\All_Reg_RunKeys\RegKeys.txt
    # Query the HKU to get a list of SID's to pull the reg keys from
    $SIDList = reg query \\$Name\HKU

    # Loop through each SID to pull the user reg run keys
    foreach ($SIDList in $SIDList)
    {
    reg query $SIDList\SOFTWARE\Microsoft\Windows\CurrentVersion\Run | out-file -append C:\All_Reg_RunKeys\UserRegKeys.txt
    reg query $SIDList\SOFTWARE\Microsoft\Windows\CurrentVersion\Run | out-file -append C:\All_Reg_RunKeys\UserRegKeys.txt
    reg query $SIDList\Environment\UserInitMprLogonScript | out-file -append C:\All_Reg_RunKeys\UserRegKeys.txt
    }
  } 
}

# Count all HKLM reg keys, sort them, and place them in the KeyCounts.txt file 
# This can be used if you create an initial whitelist of reg run keys in your environment.  
# Then, it won't count and display them again in the KeyCounts.txt file

# Ignore these keys.  If there are no keys returned that aren't in this list, the file KeyCounts.txt will be empty.
$whitelist = "nameofkey","replacethese"

# Initialize the $count HashTable (associative array)
$count=@{} 
# Read file, find lines with ’REG_SZ' and REG_EXPAND_SZ
$keynames=Get-Content C:\All_Reg_RunKeys\RegKeys.txt|select-string "REG_SZ","REG_EXPAND_SZ"
# Iterate through $keynames one key at a time
foreach ( $key in $keynames ) {
  # Remove "REG_SZ“ and "REG_EXPAND_SZ" to the end of the line. 
  $key=$key -replace " *REG_SZ.*", ""
  $key=$key -replace " *REG_EXPAND_SZ.*", ""
  # Remove extra spaces
  $key=$key.trim()
  # If itâ€™s not whitelisted
  if (-not ($whitelist -contains $key)){
    # Increment count for that key by 1
    $count[$key]++ 
  }
}
# write each key and its count, sorted from highest to lowest into the KeyCounts.txt file
$count.GetEnumerator() | sort value -Descending | out-file -append C:\All_Reg_RunKeys\KeyCounts.txt

# Count all HKU reg keys, sort them, and place them in the UserKeyCounts.txt file 
# This can be used if you create an initial whitelist of reg run keys in your environment.  
# Then, it won't count and display them again in the UserKeyCounts.txt file

# Ignore these keys. If there are no keys returned that aren't in this list, the file UserKeyCounts.txt will be empty.
$HKUwhitelist = "Sidebar"

# Initialize the $count HashTable (associative array)
$HKUcount=@{} 
# Read file, find lines with Ã’REG_EXPAND_SZÃ“
$HKUkeynames=Get-Content C:\All_Reg_RunKeys\UserRegKeys.txt|select-string "REG_SZ","REG_EXPAND_SZ"
# Iterate through $keynames one key at a time
foreach ( $HKUkey in $HKUkeynames ) {
  # Remove "REG_SZ“ and "REG_EXPAND_SZ" to the end of the line.
  $key=$key -replace " *REG_SZ.*", ""
  $HKUkey=$HKUkey -replace " *REG_EXPAND_SZ.*", ""
  # Remove extra spaces
  $HKUkey=$HKUkey.trim()
  # If it's not whitelisted
  if (-not ($HKUwhitelist -contains $HKUkey)){
    # Increment count for that key by 1
    $HKUcount[$HKUkey]++ 
  }
}
# write each key and its count, sorted from highest to lowest into the UserKeyCounts.txt file
$HKUcount.GetEnumerator() | sort value -Descending | out-file -append C:\All_Reg_RunKeys\UserKeyCounts.txt
