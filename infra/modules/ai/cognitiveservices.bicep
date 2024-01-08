param name string
param location string = resourceGroup().location
param tags object = {}

param customSubDomainName string = name
param deployments array = []
param kind string = 'OpenAI'

param disableLocalAuth bool = true // Only allow access to Azure OpenAI via managed identity
param publicNetworkAccess string = 'Disabled'
param sku object = {
  name: 'S0'
}
//param apimManagedIdentityName string
param chargeBackManagedIdentityName string
param logAnalyticsWorkspaceId string

//Private Endpoint settings
param openAiPrivateEndpointName string
param privateEndpointLocation string = location
param vNetName string
param privateEndpointSubnetName string
param openAiDnsZoneName string

// Cognitive Services OpenAI User
var roleDefinitionResourceId = '/providers/Microsoft.Authorization/roleDefinitions/5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'

// resource managedIdentityApim 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
//   name: apimManagedIdentityName
// }

resource managedIdentityChargeBack 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: chargeBackManagedIdentityName
}

resource account 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  kind: kind
  properties: {
    disableLocalAuth: disableLocalAuth 
    customSubDomainName: customSubDomainName
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: 'Deny'
    }
  }
  sku: sku
}

@batchSize(1)
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [for deployment in deployments: {
  parent: account
  name: deployment.name
  properties: {
    model: deployment.model
    raiPolicyName: contains(deployment, 'raiPolicyName') ? deployment.raiPolicyName : null
  }
  sku: contains(deployment, 'sku') ? deployment.sku : {
    name: 'Standard'
    capacity: 20
  }
}]

module privateEndpoint '../networking/private-endpoint.bicep' = {
  name: '${account.name}-privateEndpoint-deployment'
  params: {
    groupIds: [
      'account'
    ]
    dnsZoneName: openAiDnsZoneName
    name: openAiPrivateEndpointName
    subnetName: privateEndpointSubnetName
    privateLinkServiceId: account.id
    vNetName: vNetName
    location: privateEndpointLocation
  }
}

// resource roleAssignmentApim 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   scope: account
//   name: guid(managedIdentityApim.id, roleDefinitionResourceId)
//   properties: {
//     roleDefinitionId: roleDefinitionResourceId
//     principalId: managedIdentityApim.properties.principalId
//     principalType: 'ServicePrincipal'
//   }
// }

resource roleAssignmentChargeBack 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: account
  name: guid(managedIdentityChargeBack.id, roleDefinitionResourceId)
  properties: {
    roleDefinitionId: roleDefinitionResourceId
    principalId: managedIdentityChargeBack.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'LogToLogAnalytics'
  scope: account
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: []
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true 
      }
    ]
  }
}

output openAiName string = account.name
output openAiEndpointUri string = '${account.properties.endpoint}openai/'
output openAIEndpointUriRaw string = account.properties.endpoint
