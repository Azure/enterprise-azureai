$azdenv = azd env get-values --output json | ConvertFrom-Json

$targetSubscription = $azdenv.AZURE_SUBSCRIPTION_ID
$currentSubscription= az account show --query id -o tsv
if ($? -eq $false) {
    Write-Host "AZ CLI Login to the Entra ID tenant used by AZD"
    #az login --tenant $azdenv.TENANT_ID
    az login --scope https://graph.microsoft.com//.default
    az account set --subscription $targetSubscription
    $currentSubscription=(az account show --query id -o tsv)
}

az account set --subscription $targetSubscription
if ($? -eq $false) {
    Write-Host "Failed to set the subscription.."
    Write-Host "Make sure you have access and are logged in with the right tenant"
    exit 1
}

Write-Host "Current subscription set to $targetSubscription"
exit 0
