#get the environment variables 
$azdenv = azd env get-values --output json | ConvertFrom-Json

if ($azdenv.DEPLOY_AZURE_CHATAPP) {
    azd package azurechat
    azd deploy azurechat
}
