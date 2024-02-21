while IFS='=' read -r key value; do
    
    if [ "$key" == "DEPLOY_AZURE_CHATAPP" ];
    then
        if [ $value == '"true"' ];
        then
            azd package azurechat
            azd deploy azurechat
            exit
        fi
    fi
done <<EOF
$(azd env get-values) 
EOF
