param name string
param location string = resourceGroup().location
param tags object = {}
param logAnalyticsWorkspaceId string
//Private Endpoint settings
param privateLinkScopeName string
param vNetName string
param privateEndpointSubnetName string
param dnsZoneName string
param privateEndpointName string

resource privateLinkScope 'microsoft.insights/privateLinkScopes@2021-07-01-preview' existing = {
  name: privateLinkScopeName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspaceId
    publicNetworkAccessForIngestion: 'Disabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

module privateEndpoint '../networking/private-endpoint.bicep' = {
  name: '${applicationInsights.name}-privateEndpoint-deployment'
  params: {
    groupIds: [
      'azuremonitor'
    ]
    dnsZoneName: dnsZoneName
    name: privateEndpointName
    subnetName: privateEndpointSubnetName
    privateLinkServiceId: privateLinkScope.id
    vNetName: vNetName
    location: location
  }
}

resource appInsightsScopedResource 'Microsoft.Insights/privateLinkScopes/scopedResources@2021-07-01-preview' = {
  parent: privateLinkScope
  name: '${applicationInsights.name}-connection'
  properties: {
    linkedResourceId: applicationInsights.id
  }
}

output connectionString string = applicationInsights.properties.ConnectionString
output instrumentationKey string = applicationInsights.properties.InstrumentationKey
output name string = applicationInsights.name
