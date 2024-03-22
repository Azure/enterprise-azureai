# to run the script outside of the azd context, we need to set the env vars
while IFS='=' read -r key value; do
        value=$(echo "$value" | sed 's/^"//' | sed 's/"$//')
        export "$key=$value"
done <<EOF
$(azd env get-values)
EOF

echo "deploy AzureChat = $DEPLOY_AZURE_CHATAPP"
    
if [ $DEPLOY_AZURE_CHATAPP ]
then
    echo "checking app registration"
    ./scripts/appreg.sh
    echo "deploying azurechat"
    azd deploy azurechat
fi 
