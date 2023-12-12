param name string 
param location string
param AzureMonitorDataCollectionEndPointUrl string
param AzureMonitorDataCollectionRuleImmutableId string
param AzureMonitorDataCollectionRuleStream string
param AzureOpenAIEndpoints array

resource appconfig 'Microsoft.AppConfiguration/configurationStores@2023-03-01' = {
  name: name
  location: location
  sku: {
    name: 'Standard'
  }
}

resource dataCollectionEndpoint 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = {
  name: 'AzureMonitor:DataCollectionEndPoint'
  parent: appconfig
  properties:{
    value: AzureMonitorDataCollectionEndPointUrl
  }
}

resource dataCollectionRuleImmutableId 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = {
  name: 'AzureMonitor:DataCollectionRuleImmutableId'
  parent: appconfig
  properties:{
    value: AzureMonitorDataCollectionRuleImmutableId
  }
}

resource dataCollectionRuleStream 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = {
  name: 'AzureMonitor:DataCollectionRuleStream'
  parent: appconfig
  properties:{
    value: AzureMonitorDataCollectionRuleStream
  }
}

resource EntraIdTenantId 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = {
  name: 'EntraId:TenantId'
  parent: appconfig
  properties:{
    value: subscription().tenantId
  }
}

var flatArray = replace(replace(string(AzureOpenAIEndpoints), '(', '['), ')', ']')

resource azureOpenAIEndpoints 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = {
  name: 'AzureOpenAI:Endpoints'
  parent: appconfig
  properties:{
    value: flatArray
  }
}

