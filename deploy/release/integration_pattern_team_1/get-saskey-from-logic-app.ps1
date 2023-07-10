param ($subscriptionId, $resourceGroup, $logicAppName, $workflowName, $apimName, $apimNamedValueSig)

$workflowDetails = az rest --method post --uri https://management.azure.com/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Web/sites/$logicAppName/hostruntime/runtime/webhooks/workflow/api/management/workflows/$workflowName/triggers/manual/listCallbackUrl?api-version=2018-11-01

$json = $workflowDetails | ConvertFrom-Json
$sig = ($json.queries | Where-Object sig).sig

az apim nv create --service-name $apimName -g $resourceGroup --named-value-id $apimNamedValueSig --display-name $apimNamedValueSig --secret true --value $sig