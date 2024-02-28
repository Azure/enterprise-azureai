myip=$(curl -4 icanhazip.com)
azd env set MY_IP_ADDRESS $myip

sh ./scripts/set-az-currentsubscription.sh
if [ $? -eq 0 ]
then
    myprincipal=$(az ad signed-in-user show --query "id" -o tsv)
    azd env set MY_USER_ID $myprincipal
fi
