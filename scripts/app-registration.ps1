$azdenv = azd env get-values --output json | ConvertFrom-Json
$context = Get-AzContext


if ($context.Account.ExtendedProperties.Subscriptions -contains $azdenv.AZURE_SUBSCRIPTION_ID) {
    Write-Host "Already logged in to the correct subscription.."
} else {
    Connect-AzAccount -AuthScope MicrosoftGRaphEndPointResourceId `
                      -subscription $azdenv.AZURE_SUBSCRIPTION_ID `
                      -tenant $azdenv.TENTANT_ID
}

$displayName = "Enterprise-AzureAI-ChatApp-" + $azdenv.RESOURCE_TOKEN
$app = Get-AzADApplication -DisplayName $displayName

if ($app) {
    Write-Host "Application already exists"
    Write-Host $app.ApplicationId
}
else {
    $localReplyUrl = "http://localhost:3000/api/auth/callback/azure-ad"
    $azureReplyUrl = $azdenv.CHATAPP_URL + "api/auth/callback/azure-ad"
    $redirectUris = @($localReplyUrl, $azureReplyUrl)

    $app = New-AzADApplication -SignInAudience AzureADMyOrg `
                                -DisplayName $displayName `
                                -ReplyUrls $redirectUris
}

$creds = Get-AzADAppCredential -ObjectId $app.Id 
if ($creds.DisplayName -contains 'azurechat-secret') {
    Write-Host "Credentials already exist"
} else {
    $PasswordCedentials = @(
        @{
            StartDateTime = Get-Date
            EndDateTime = (Get-Date).AddDays(90)
            DisplayName = "azurechat-secret"
        }
    )
    $secret = New-AzADAppCredential -ObjectId $app.Id -PasswordCredentials $PasswordCedentials
}
                           

Write-Host $app.AppId
Write-Host $app.Id
Write-Host $secret

if ($secret) {
    $secretValue = ConvertTo-SecureString $secret.SecretText -AsPlainText -Force
    Set-AzKeyVaultSecret -VaultName "kv-d2zff763zvpfy" `
                         -Name "AzureChatClientSecret" `
                         -SecretValue $secretValue

    $secretValue = ConvertTo-SecureString $app.AppId -AsPlainText -Force
    Set-AzKeyVaultSecret -VaultName "kv-d2zff763zvpfy" `
                         -Name "AzureChatClientId" `
                         -SecretValue $secretValue
}
