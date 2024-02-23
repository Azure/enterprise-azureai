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
fi

az account set --subscription $targetSubscription
if [ $? -eq 1 ];
then
    echo "Failed to set the subscription.."
    echo "Make sure you have access and are logged in with the right tenant"
    exit 1
fi

az ad app delete --id $AZURE_CHATAPP_CLIENT_ID