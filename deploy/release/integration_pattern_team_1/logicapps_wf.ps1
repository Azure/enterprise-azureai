param ($subscriptionId, $resourceGroup, $logicAppName, $workflowPathGet, $workflowPathPost, $workflowPathProcessSubOds, $sqlConnectionString, $serviceBusConnectionString, $destinationPath)

Write-Host "Setting the paramaters:"
Write-Host "Subscription id: "$subscriptionId
Write-Host "Resource Group: "$resourceGroup
Write-Host "Logic App Name: "$logicAppName
Write-Host "Workflow Path Get: "$workflowPathGet
Write-Host "Workflow Path Post: "$workflowPathPost
Write-Host "Workflow Path Process updates to ODS: "$workflowPathProcessSubOds
Write-Host "Destination Path ZIP Deployment: "$destinationPath

Write-Host "Release Workflows to Logic App:"
$compress = @{
    Path = $workflowPathGet, $workflowPathPost, $workflowPathProcessSubOds, ".\host.json", ".\connections.json"
    CompressionLevel = "Fastest"
    DestinationPath = $destinationPath
}
Compress-Archive @compress -Force

az logicapp deployment source config-zip -g $resourceGroup -n $logicAppName --subscription $subscriptionId --src $destinationPath

Write-Host "Set connection strings in AppSettings:"
az webapp config appsettings set -g $resourceGroup -n $logicAppName --settings sql_connectionString=$sqlConnectionString
az webapp config appsettings set -g $resourceGroup -n $logicAppName --settings serviceBus_connectionString=$serviceBusConnectionString