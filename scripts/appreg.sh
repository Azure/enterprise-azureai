while IFS='=' read -r key value; do
    value=$(echo "$value" | sed 's/^"//' | sed 's/"$//')
    export "$key=$value"
done <<EOF
$(azd env get-values)
EOF

targetSubscription=$AZURE_SUBSCRIPTION_ID
currentSubscription=$(az account show --query id -o tsv)
if [ $? -eq 1 ];
then
    echo "AZ CLI Login to the Entra ID tenant used by AZD"
    az login --tenant $TENANT_ID
    az account set --subscription $targetSubscription
    currentSubscription=(az account show --query id -o tsv)
fi

az account set --subscription $targetSubscription
if [ $? -eq 1 ];
then
    echo "Failed to set the subscription.."
    echo "Make sure you have access and are logged in with the right tenant"
    exit 1
fi

echo "Current Subscription: $currentSubscription"

#check if registration exists
displayName="Enterprise-AzureAI-ChatApp-$RESOURCE_TOKEN"
app=$(az ad app list --display-name $displayName )


if [ "$app" == "[]" ];
then
    echo "App registration $displayName does not exist..."
    localReplyUrl="http://localhost:3000/api/auth/callback/azure-ad"
    azureReplyUrl="$AZURE_CHATAPP_URL/api/auth/callback/azure-ad"
    redirectUris="$localReplyUrl $azureReplyUrl"

    app=$(az ad app create --display-name $displayName \
                        --web-redirect-uris $redirectUris \
                        --sign-in-audience AzureADMyOrg \
                        --output json | jq -r '.')

    echo "New App registration $displayName created successfully..."

    echo "Create Secret Credentials"
    cred=$(az ad app credential reset --id $(echo $app | jq -r '.appId') \
                                    --display-name "azurechat-secret" \
                                    --output json | jq -r '.')


    echo "Secret Credentials created successfully..."
    echo "Create Key Vault Secrets"

    s1=$(az keyvault secret set --name AzureChatClientSecret \
                                --vault-name $AZURE_CHATAPP_KEYVAULT_NAME \
                                --value $(echo $cred | jq -r '.password') \
                                --output json | jq -r '.')

    s2=$(az keyvault secret set --name AzureChatClientId \
                                --vault-name $AZURE_CHATAPP_KEYVAULT_NAME \
                                --value $(echo $app | jq -r '.appId') \
                                --output json | jq -r '.')
else
    echo "Application already exists"
fi