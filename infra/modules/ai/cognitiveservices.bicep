param name string
param location string = resourceGroup().location
param tags object = {}

param customSubDomainName string = name
param deployments array = []
param kind string = 'OpenAI'
param publicNetworkAccess string = 'Disabled'
param sku object = {
  name: 'S0'
}
param apimManagedIdentityName string
//Private Endpoint settings
/*
param openAiPrivateEndpointName string
param vNetName string
param privateEndpointSubnetName string
param openAiDnsZoneName string
*/
// Cognitive Services OpenAI User
var roleDefinitionResourceId = '/providers/Microsoft.Authorization/roleDefinitions/5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'

resource managedIdentityApim 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: apimManagedIdentityName
}

resource account 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  kind: kind
  properties: {
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
/*
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
    location: location
  }
}
*/
resource roleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: account
  name: guid(account.id, roleDefinitionResourceId)
  properties: {
    roleDefinitionId: roleDefinitionResourceId
    principalId: managedIdentityApim.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output openAiName string = account.name
output openAiEndpointUri string = '${account.properties.endpoint}openai/'
