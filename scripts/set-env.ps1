$myip = curl -4 icanhazip.com
azd env set MY_IP_ADDRESS $myip

$myPrincipal = az ad signed-in-user show --query "id" -o tsv
azd env set MY_USER_ID $myPrincipal


