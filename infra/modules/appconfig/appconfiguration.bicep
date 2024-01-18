param name string 
param location string
param AzureMonitorDataCollectionEndPointUrl string
param AzureMonitorDataCollectionRuleImmutableId string
param AzureMonitorDataCollectionRuleStream string
param AzureOpenAIEndpoints array
param proxyManagedIdentityName string
param ProxyConfig object

// App Configuration Data Reader role definition
var roleDefinitionId = '516239f1-63e1-4d78-a4de-a74fb236a071'

resource proxyIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: proxyManagedIdentityName
}


resource appconfig 'Microsoft.AppConfiguration/configurationStores@2023-03-01' = {
  name: name
  location: location
  sku: {
    name: 'Standard'
  }
}

module roleAssignment '../roleassignments/roleassignment.bicep' = {
  name: 'roleAssignment'
  params: {
    principalId: proxyIdentity.properties.principalId
    roleDefinitionId: roleDefinitionId
    targetResourceId: appconfig.id
    deploymentName: 'proxy-roleassignment-AppConfigurationDataReader'
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

resource proxyConfig 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = {
  name: 'AzureAIProxy:ProxyConfig'
  parent: appconfig
  properties:{
    value: replace(string(ProxyConfig),',{}', '')
  }
}

output appConfigEndPoint string = appconfig.properties.endpoint

