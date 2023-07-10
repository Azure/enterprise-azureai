@minLength(3)
@maxLength(11)
param namePrefix string
param location string
param appInsightsInstrKey string
param appInsightsEndpoint string
param storageConnectionString string

var uniqueLogicAppName = '${namePrefix}${uniqueString(resourceGroup().id)}-la'
var appServicePlanName = '${namePrefix}-asp'
var logicAppEnabledState = true

resource serverFarm 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'WS1'
    capacity: 1
  }
}

resource logicApp 'Microsoft.Web/sites@2021-02-01' = {
  name: uniqueLogicAppName
  location: location
  kind: 'functionapp,workflowapp'
  identity: {
      type: 'SystemAssigned'
  }
  properties: {
    enabled: logicAppEnabledState
    serverFarmId: serverFarm.id
    clientAffinityEnabled: true
    siteConfig: {
      appSettings: [
        {
          'name': 'APP_KIND'
          'value': 'workflowApp'
        }
        {
          'name': 'APPINSIGHTS_INSTRUMENTATIONKEY'
          'value': appInsightsInstrKey
        }
        {
          'name': 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          'value': appInsightsEndpoint
        }
        {
          'name': 'AzureFunctionsJobHost__extensionBundle__id'
          'value': 'Microsoft.Azure.Functions.ExtensionBundle.Workflows'
        }
        {
          'name': 'AzureFunctionsJobHost__extensionBundle__version'
          'value': '[1.*, 2.0.0)'
        }
        {
          'name': 'AzureWebJobsStorage'
          'value': storageConnectionString
        }
        {
          'name': 'FUNCTIONS_EXTENSION_VERSION'
          'value': '~3'
        }
        {
          'name': 'FUNCTIONS_WORKER_RUNTIME'
          'value': 'node'
        }
        {
          'name': 'WEBSITE_NODE_DEFAULT_VERSION'
          'value': '~12'
        }
      ]
    }
  }
}

output logicAppName string = logicApp.name
output appServicePlanName string = serverFarm.name
