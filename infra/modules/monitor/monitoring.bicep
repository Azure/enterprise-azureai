param logAnalyticsName string
param applicationInsightsName string
param dataCollectionEndpointName string
param dataCollectionRuleName string
param location string = resourceGroup().location
param tags object = {}
//Private Endpoint settings
param vNetName string
param privateEndpointSubnetName string
param applicationInsightsDnsZoneName string
param applicationInsightsPrivateEndpointName string
param applicationInsightsDashboardName string
param chargeBackManagedIdentityName string

var privateLinkScopeName = 'private-link-scope'

resource privateLinkScope 'microsoft.insights/privateLinkScopes@2021-07-01-preview' = {
  name: privateLinkScopeName
  location: 'global'
  properties: {
    accessModeSettings: {
      ingestionAccessMode: 'Open'
      queryAccessMode: 'Open'
    }
  }
}

module logAnalytics 'loganalytics.bicep' = {
  name: 'log-analytics'
  params: {
    name: logAnalyticsName
    location: location
    tags: tags
    privateLinkScopeName: privateLinkScopeName
  }
}

module applicationInsights 'applicationinsights.bicep' = {
  name: 'application-insights'
  params: {
    name: applicationInsightsName
    location: location
    tags: tags
    logAnalyticsWorkspaceId: logAnalytics.outputs.resourceId
    //Private Endpoint settings
    privateLinkScopeName: privateLinkScopeName
    vNetName: vNetName
    privateEndpointSubnetName: privateEndpointSubnetName
    dnsZoneName: applicationInsightsDnsZoneName
    privateEndpointName: applicationInsightsPrivateEndpointName
  }
}

module dashboard 'dashboard.bicep' = {
  name: 'application-insights-dashboard'
  params: {
    name: applicationInsightsDashboardName
    location: location
    applicationInsightsName: applicationInsights.outputs.name
    logAnalyticsWorkspaceName: logAnalytics.outputs.name
  }
}

module loganalyticsCustomTable 'loganatylicscustomtable.bicep' = {
  name: 'log-analytics-custom-table'
  params:{
    logAnalyticsWorkspaceName: logAnalytics.outputs.name
  }
}

module dataCollectionEndpoint 'datacollectionendpoint.bicep' = {
  name: 'data-collection-endpoint'
  params: {
    name: dataCollectionEndpointName
    location: location
  }
}

module dataCollectionRule 'datacollectionrule.bicep' = {
  name: 'data-collection-rule'
  dependsOn: [
    loganalyticsCustomTable
  ]
  params: {
    dataCollectionEndpointResourceId: dataCollectionEndpoint.outputs.dataCollectionEndpointResourceId
    logAnalyticsWorkspaceResourceId: logAnalytics.outputs.resourceId
    name: dataCollectionRuleName
    location: location
    tags: tags
    proxyManagedIdentityName: chargeBackManagedIdentityName
  }
}

output applicationInsightsConnectionString string = applicationInsights.outputs.connectionString
output applicationInsightsInstrumentationKey string = applicationInsights.outputs.instrumentationKey
output applicationInsightsName string = applicationInsights.outputs.name
output logAnalyticsWorkspaceId string = logAnalytics.outputs.resourceId
output logAnalyticsWorkspaceName string = logAnalytics.outputs.name
output dataCollectionEndpointUrl string = dataCollectionEndpoint.outputs.dataCollectionEndPointLogIngestionUrl
output dataCollectionRuleImmutableId string = dataCollectionRule.outputs.dataCollectionRuleImmutableId
output dataCollectionRuleStreamName string = dataCollectionRule.outputs.dataCollectionRuleStreamName

