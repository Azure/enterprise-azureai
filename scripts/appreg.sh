# to run the script outside of the azd context, we need to set the env vars
while IFS='=' read -r key value; do
        value=$(echo "$value" | sed 's/^"//' | sed 's/"$//')
        export "$key=$value"
done <<EOF
$(azd env get-values)
EOF

#run az login and set correct subscription if needed
./scripts/set-az-currentsubscription.sh
if [ $? -eq 0 ];
then

    displayName="Enterprise-AzureAI-ChatApp-$RESOURCE_TOKEN"
    app=$(az ad app list --display-name $displayName --output json | jq -r '.[0].appId // empty')

    if [ -z $app ];
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
                                    
        azd env set AZURE_CHATAPP_CLIENT_ID $(echo $app | jq -r '.appId')
    else
        echo "Application registration $displayName already exists"
    fi
fi