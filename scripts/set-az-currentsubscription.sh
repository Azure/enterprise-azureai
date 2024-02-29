# to run the script outside of the azd context, we need to set the env vars
while IFS='=' read -r key value; do
    value=$(echo "$value" | sed 's/^"//' | sed 's/"$//')
    export "$key=$value"
done <<EOF
$(azd env get-values)
EOF

targetSubscription=$AZURE_SUBSCRIPTION_ID
currentSubscription=$(az account show --query id -o tsv)
if [ $? -eq 1 ]
then
    echo "AZ CLI Login to the Entra ID tenant used by AZD"
    az login --scope https://graph.microsoft.com//.default
    az account set --subscription $targetSubscription
    currentSubscription=$(az account show --query id -o tsv)
fi

az account set --subscription $targetSubscription
if [ $? -eq 1 ]
then
    echo "Failed to set the subscription.."
    echo "Make sure you have access and are logged in with the right tenant"
    exit 1
fi

echo "Current Subscription: $targetSubscription"
exit 0