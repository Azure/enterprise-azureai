
if ($? -eq $true) {
    #get the environment variables 
    $azdenv = azd env get-values --output json | ConvertFrom-Json

    if ($azdenv.DEPLOY_AZURE_CHATAPP -eq "true") {
    
        Write-Host "Deploying Azure Chat App..."

        azd env set AZURE_RESOURCE_GROUP $azdenv.AZURECHAT_RESOURCE_GROUP
        ./scripts/appreg.ps1
        azd deploy azurechat
        azd env set AZURE_RESOURCE_GROUP $azdenv.MAIN_RESOURCE_GROUP

        Write-Host "Azure Chat App deployed successfully..."
    }     
    else {
        Write-Host "Azure Chat App deployment is not enabled..."
    }
}