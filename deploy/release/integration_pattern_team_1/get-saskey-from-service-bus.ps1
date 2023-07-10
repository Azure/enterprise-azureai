param ($serviceBusUri, $accessPolicyName, $accessPolicyKey, $apimName, $resourceGroup, $apimNamedValueSig)

$expires=([DateTimeOffset]::Now.ToUnixTimeSeconds())+31587840
$signatureString=[System.Web.HttpUtility]::UrlEncode($serviceBusUri)+ "`n" + [string]$expires
$HMAC = New-Object System.Security.Cryptography.HMACSHA256
$HMAC.key = [Text.Encoding]::ASCII.GetBytes($accessPolicyKey)
$signature = $HMAC.ComputeHash([Text.Encoding]::ASCII.GetBytes($signatureString))
$signature = [Convert]::ToBase64String($signature)
$sasToken = "SharedAccessSignature sr=" + [System.Web.HttpUtility]::UrlEncode($serviceBusUri) + "&sig=" + [System.Web.HttpUtility]::UrlEncode($signature) + "&se=" + $expires + "&skn=" + $accessPolicyName

az apim nv create --service-name $apimName -g $resourceGroup --named-value-id $apimNamedValueSig --display-name $apimNamedValueSig --value $sasToken --secret true