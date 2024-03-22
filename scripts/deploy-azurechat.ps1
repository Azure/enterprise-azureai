
if ($? -eq $true) {
    #get the environment variables 
    $azdenv = azd env get-values --output json | ConvertFrom-Json

    if ($azdenv.DEPLOY_AZURE_CHATAPP -eq "true") {
    
        Write-Host "Deploying Azure Chat App..."
        ./scripts/appreg.ps1
        azd deploy azurechat
        Write-Host "Azure Chat App deployed successfully..."
    }     
    else {
        Write-Host "Azure Chat App deployment is not enabled..."
    }
}