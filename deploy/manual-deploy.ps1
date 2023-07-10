param ($subscriptionId, $namePrefix)

Write-Host "Setting the paramaters:"
$location = "westeurope"
$resourceGroup = "$namePrefix-rg"
$buildBicepPath = ".\deploy\build\main.bicep"
$releaseAPIMBicepPath = ".\deploy\release\apim_apis.bicep"
$deploymentNameBuild = $namePrefix+"build"
$deploymentNameAPIMRelease = $namePrefix+"apimrelease"

Write-Host "Login to Azure:"
az login
Set-AzContext -Subscription $subscriptionId

Write-Host "Build"
Write-Host "Deploy Infrastructure as Code:"
New-AzSubscriptionDeployment -name $deploymentNameBuild -namePrefix $namePrefix -location $location -TemplateFile $buildBicepPath

Write-Host "Release"
Write-Host "Retrieve API Management Instance & Application Insights Name:"
$apimName = az apim list --resource-group $resourceGroup --subscription $subscriptionId --query "[].{Name:name}" -o tsv
$appInsightsName = az monitor app-insights component show -g $resourceGroup --query "[].{applicationId:applicationId}" -o tsv
Write-Host "API Management Instance:"$apimName
Write-Host "Application Insights:"$appInsightsName

Write-Host "Release API definition to API Management:"
New-AzResourceGroupDeployment -Name $deploymentNameAPIMRelease -ResourceGroupName $resourceGroup -apimName $apimName -appInsightsName $appInsightsName -TemplateFile $releaseAPIMBicepPath
