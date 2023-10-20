$subscriptionId = "53a3db51-5b77-4e0e-bb8b-b287f39ac108"
$apimName = "apim-fgnax57ck7wmu"
Connect-AzAccount
Set-AzContext -Subscription $subscriptionId
.\del-soft-delete-apim.ps1 -subscriptionId $subscriptionId -apimName $apimName