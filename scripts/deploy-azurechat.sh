while IFS='=' read -r key value; do
    
    if [ "$key" == "DEPLOY_AZURE_CHATAPP" ];
    then
        if [ $value == '"true"' ];
        then
            ./scripts/appreg.sh
            azd package azurechat
            azd deploy azurechat
            exit
        else
            echo "Azure ChatApp deployment is disabled"
            exit
        fi
    fi
done <<EOF
$(azd env get-values) 
EOF
