#run az login and set correct subscription if needed
./scripts/set-az-currentsubscription.ps1

if ($? -eq $true) {

    $azdenv = azd env get-values --output json | ConvertFrom-Json

    #check if registration exists
    $displayName = "Enterprise-AzureAI-ChatApp-" + $azdenv.RESOURCE_TOKEN
    $app = az ad app list --display-name $displayName --output json | ConvertFrom-Json

    if (!$app) {
        Write-Host "Creating new app registration $displayName..."
    
        $localReplyUrl = "http://localhost:3000/api/auth/callback/azure-ad"
        $azureReplyUrl = $azdenv.AZURE_CHATAPP_URL + "/api/auth/callback/azure-ad"
        $redirectUris = @($localReplyUrl, $azureReplyUrl)

        $app = az ad app create --display-name $displayName `
            --web-redirect-uris $redirectUris `
            --sign-in-audience AzureADMyOrg `
            --output json | ConvertFrom-Json

        Write-Host "New App registration $displayName created successfully..."

        Write-Host "Create Secret Credentials"
        $cred = az ad app credential reset --id $app.appId `
            --display-name "azurechat-secret" `
            --output json | ConvertFrom-Json

        Write-Host "Secret Credentials created successfully..."
        Write-Host "Create Key Vault Secrets"

        $s1 = az keyvault secret set --name AzureChatClientSecret `
            --vault-name $azdenv.AZURE_CHATAPP_KEYVAULT_NAME `
            --value $cred.password `
            --output json | ConvertFrom-Json

        $s2 = az keyvault secret set --name AzureChatClientId `
            --vault-name $azdenv.AZURE_CHATAPP_KEYVAULT_NAME `
            --value $app.appId `
            --output json | ConvertFrom-Json
        
        azd env set AZURE_CHATAPP_CLIENT_ID $app.appId 
    }
    else {
        Write-Host "Application registration $displayName already exists"
    }
}