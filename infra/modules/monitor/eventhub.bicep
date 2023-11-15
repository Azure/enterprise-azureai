param name string
param eventHubName string
param eventHubListenPolicyName string
param eventHubSendPolicyName string
param location string = resourceGroup().location
param tags object = {}
param sku string = 'Standard'
//Private Endpoint settings
param eventHubPrivateEndpointName string
param vNetName string
param privateEndpointSubnetName string
param eventHubDnsZoneName string

param publicNetworkAccess string = 'Disabled'
param apimManagedIdentityName string
param funcManagedIdentityName string

// Azure Event Hubs Data Sender
var roleDefinitionResourceId = '/providers/Microsoft.Authorization/roleDefinitions/2b629674-e913-4c01-ae53-ef4638d8f975'

resource managedIdentityApim 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: apimManagedIdentityName
}

resource managedIdentityFunc 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: funcManagedIdentityName
}

resource eventHubNamespace 'Microsoft.EventHub/namespaces@2022-10-01-preview' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  sku: {
    name: sku
    tier: sku
    capacity: 1
  }
  properties: {
    isAutoInflateEnabled: false
    maximumThroughputUnits: 0
    publicNetworkAccess: publicNetworkAccess
  }
}

resource eventHub 'Microsoft.EventHub/namespaces/eventhubs@2022-10-01-preview' = {
  parent: eventHubNamespace
  name: eventHubName
  properties: {
    messageRetentionInDays: 7
    partitionCount: 1
  }
}

resource eventHubVirtualNetworkRule 'Microsoft.EventHub/namespaces/networkRuleSets@2022-01-01-preview' = {
  name: 'default'
  parent: eventHubNamespace
  properties: {
    defaultAction: 'Deny'
    ipRules: []
    publicNetworkAccess: publicNetworkAccess
  }
}

resource eventHubListener 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2022-01-01-preview' = {
  parent: eventHub
  name: eventHubListenPolicyName
  properties: {
    rights: [
      'Listen'
    ]
  }
}

resource eventHubSend 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2022-01-01-preview' = {
  parent: eventHub
  name: eventHubSendPolicyName
  properties: {
    rights: [
      'Send'
    ]
  }
}
//Private Endpoint
module privateEndpoint '../networking/private-endpoint.bicep' = {
  name: '${eventHubNamespace.name}-privateEndpoint-deployment'
  params: {
    groupIds: [
      'namespace'
    ]
    dnsZoneName: eventHubDnsZoneName
    name: eventHubPrivateEndpointName
    subnetName: privateEndpointSubnetName
    privateLinkServiceId: eventHubNamespace.id
    vNetName: vNetName
    location: location
  }
}

resource roleAssignmentApim 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: eventHubNamespace
  name: guid(managedIdentityApim.id, roleDefinitionResourceId)
  properties: {
    roleDefinitionId: roleDefinitionResourceId
    principalId: managedIdentityApim.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource roleAssignmentFunc 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: eventHubNamespace
  name: guid(managedIdentityFunc.id, roleDefinitionResourceId)
  properties: {
    roleDefinitionId: roleDefinitionResourceId
    principalId: managedIdentityFunc.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

output eventHubNamespaceName string = eventHubNamespace.name
output eventHubName string = eventHub.name
output eventHubListenPolicyName string = eventHubListener.name
output eventHubSendPolicyName string = eventHubSend.name
