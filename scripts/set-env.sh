myip=$(curl -4 icanhazip.com)
azd env set MY_IP_ADDRESS $myip
myprincipal=$(az ad signed-in-user show --query "id" -o tsv)
echo $myprincipal
azd env set MY_USER_ID $myprincipal
