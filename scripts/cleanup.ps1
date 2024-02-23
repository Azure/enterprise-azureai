$azdenv = azd env get-values --output json | ConvertFrom-Json

$currentSubscription= az account show --query id -o tsv
if ($? -eq $false) {
    Write-Host "AZ CLI Login to the Entra ID tenant used by AZD"
    az login --tenant $azdenv.TENANT_ID
    az account set --subscription $targetSubscription
    $currentSubscription=(az account show --query id -o tsv)
}

az ad app delete --id $azdenv.AZURE_CHATAPP_CLIENT_ID