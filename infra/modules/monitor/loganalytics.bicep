param name string
param location string = resourceGroup().location
param tags object = {}
//Private Endpoint
param privateLinkScopeName string

resource privateLinkScope 'microsoft.insights/privateLinkScopes@2021-07-01-preview' existing = {
  name: privateLinkScopeName
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
    publicNetworkAccessForIngestion: 'Disabled'
    publicNetworkAccessForQuery: 'Enabled'
  })
}

//Private Endpoint
resource logAnalyticsScopedResource 'Microsoft.Insights/privateLinkScopes/scopedResources@2021-07-01-preview' = {
  parent: privateLinkScope
  name: '${logAnalytics.name}-connection'
  properties: {
    linkedResourceId: logAnalytics.id
  }
}

// resource roleAssignmentChargeBack 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   scope: logAnalytics
//   name: guid(managedIdentityChargeBack.id, roleDefinitionResourceId)
//   properties: {
//     roleDefinitionId: roleDefinitionResourceId
//     principalId: managedIdentityChargeBack.properties.principalId
//     principalType: 'ServicePrincipal'
//   }
// }

output resourceId string = logAnalytics.id
output name string = logAnalytics.name
