param name string 
param azureMonitorDataCollectionEndPointUrl string
param azureMonitorDataCollectionRuleImmutableId string
param azureMonitorDataCollectionRuleStream string
param proxyManagedIdentityName string
param proxyConfig object
param myPrincipalId string 


resource proxyIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: proxyManagedIdentityName
}

resource appconfig 'Microsoft.AppConfiguration/configurationStores@2023-03-01' existing = {
  name: name
}

module proxyRoleAssignment '../roleassignments/roleassignment.bicep' = {
  name: 'proxy-roleAssignment'
  params: {
    principalId: proxyIdentity.properties.principalId
    roleName: 'App Configuration Data Reader'
    targetResourceId: appconfig.id
    deploymentName: 'proxy-roleassignment-AppConfigurationDataReader'
  }
}

module currentUserRoleAssignment '../roleassignments/roleassignment.bicep' = {
  name: 'currentuser-roleAssignment'
  params: {
    principalId: myPrincipalId
    roleName: 'App Configuration Data Reader'
    targetResourceId: appconfig.id
    deploymentName: 'currentuser-roleassignment-AppConfigurationDataReader'
    principalType: 'User'
  }
}



module dataCollectionEndpoint 'configurationStoreKeyValues.bicep' = {
  name: 'AzureMonitor-DataCollectionEndPoint'
  params: {
    appconfigName : appconfig.name
    key : 'AzureMonitor:DataCollectionEndPoint'
    value: azureMonitorDataCollectionEndPointUrl
  }
}

module dataCollectionRuleImmutableId 'configurationStoreKeyValues.bicep' = {
  name: 'AzureMonitor-DataCollectionRuleImmutableId'
  params:{
    appconfigName : appconfig.name
    key: 'AzureMonitor:DataCollectionRuleImmutableId'
    value: azureMonitorDataCollectionRuleImmutableId
  }
}

module dataCollectionRuleStream 'configurationStoreKeyValues.bicep' = {
  name: 'AzureMonitor-DataCollectionRuleStream'
  params: {
    appconfigName : appconfig.name
    key : 'AzureMonitor:DataCollectionRuleStream'
    value: azureMonitorDataCollectionRuleStream
  }
}

module EntraIdTenantId 'configurationStoreKeyValues.bicep' = {
  name: 'EntraId-TenantId'
  params: {
    appconfigName : appconfig.name
    key : 'EntraId:TenantId'
    value: subscription().tenantId
  }
}

module proxyConfiguration 'configurationStoreKeyValues.bicep' = {
  name: 'AzureAIProxy-ProxyConfig'
  params: {
    appconfigName : appconfig.name
    key : 'AzureAIProxy:ProxyConfig'
    value: replace(string(proxyConfig),',{}', '')
  }
}

