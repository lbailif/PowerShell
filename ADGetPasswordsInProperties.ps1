# Modified version of script to search properties in AzureAD that was written by Beau at BHIS, @dafthack
Import-Module activedirectory
$users = get-aduser -Filter *
 foreach($user in $users){$props = @();$user | Get-Member | foreach-object{$props+=$_.Name}; foreach($prop in $props){if($user.$prop -like “*password*”){Write-Output (“[*]” + $user.UserPrincipalName + “[“ + $prop + “]” + “ : “ + $user.$prop)}}}
