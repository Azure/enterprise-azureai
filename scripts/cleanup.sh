# to run the script outside of the azd context, we need to set the env vars
while IFS='=' read -r key value; do
    value=$(echo "$value" | sed 's/^"//' | sed 's/"$//')
    export "$key=$value"
done <<EOF
$(azd env get-values)
EOF

./scripts/set-az-currentsubscription.sh
if [ $? -eq 0 ];
then
    az ad app delete --id $AZURE_CHATAPP_CLIENT_ID
fi