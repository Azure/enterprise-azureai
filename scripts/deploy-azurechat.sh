
while IFS='=' read -r key value; do
    
    if [ "$key" == "DEPLOY_AZURE_CHATAPP" ];
    then
        if [ $value == '"true"' ];
        then
            azd env set AZURE_RESOURCE_GROUP "$AZURECHAT_RESOURCE_GROUP"
            ./scripts/appreg.sh
            azd deploy azurechat
            azd env set AZURE_RESOURCE_GROUP "$MAIN_RESOURCE_GROUP"
            exit
        else
            echo "Azure ChatApp deployment is disabled"
            exit
        fi
    fi
done <<EOF
$(azd env get-values) 
EOF
