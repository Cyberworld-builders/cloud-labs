# Connect to Exchange Online and Azure AD
Connect-ExchangeOnline -UserPrincipalName "admin@yourtenant.onmicrosoft.com"
Connect-AzureAD

# Convert users to room mailboxes
$rooms = Get-AzureADUser | Where-Object { $_.UserPrincipalName -like "room*@yourtenant.onmicrosoft.com" }
foreach ($room in $rooms) {
    Set-Mailbox -Identity $room.UserPrincipalName -Type Room
    Set-CalendarProcessing -Identity $room.UserPrincipalName -AutomateProcessing AutoAccept
}

# Verify GAL visibility
Get-Mailbox -RecipientTypeDetails RoomMailbox | Select-Object Name, HiddenFromAddressListsEnabled