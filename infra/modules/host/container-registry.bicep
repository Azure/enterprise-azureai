param name string
param location string = resourceGroup().location
param tags object = {}
param proxyManagedIdentityName string
param chatappManagedIdentityName string
param myIpAddress string = ''
param containerRegistryDnsZoneName string = ''
param containerRegistryPrivateEndpointName string = ''
param privateEndpointSubnetName string = ''
param vNetName string = ''


@description('Indicates whether admin user is enabled')
param adminUserEnabled bool = false

@description('Indicates whether anonymous pull is enabled')
param anonymousPullEnabled bool = false

@description('Indicates whether data endpoint is enabled')
param dataEndpointEnabled bool = false

@description('Encryption settings')
param encryption object = {
  status: 'disabled'
}

@description('Options for bypassing network rules')
param networkRuleBypassOptions string = 'AzureServices'

@description('Public network access setting')
param publicNetworkAccess string = 'Disabled'

@description('SKU settings - you need Premium sku to enable private networking')
param sku object = {
  name: 'Premium'
}

@description('Zone redundancy setting')
param zoneRedundancy string = 'Disabled'

@description('The log analytics workspace ID used for logging and monitoring')
param workspaceId string = ''

// Acr Pull role definition
var roleDefinitionResourceId = '/providers/Microsoft.Authorization/roleDefinitions/7f951dda-4ed3-4680-a7ca-43fe172d538d'

resource managedIdentityProxy 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: proxyManagedIdentityName
}

resource managedIdentityChatapp 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: chatappManagedIdentityName
}

// 2022-02-01-preview needed for anonymousPullEnabled
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  sku: sku
  properties: {
    adminUserEnabled: adminUserEnabled
    anonymousPullEnabled: anonymousPullEnabled
    dataEndpointEnabled: dataEndpointEnabled
    encryption: encryption
    networkRuleBypassOptions: networkRuleBypassOptions
    publicNetworkAccess: publicNetworkAccess
    zoneRedundancy: zoneRedundancy
    networkRuleSet: myIpAddress == '' ? null : {
      defaultAction: 'Deny'
      ipRules: [
        {
          action: 'Allow'
          value: myIpAddress
        }
      ]
    }
  }
}

module privateEndpoint '../networking/private-endpoint.bicep' = {
  name: '${containerRegistry.name}-privateEndpoint-deployment'
  params: {
    groupIds: [
      'registry'
    ]
    dnsZoneName: containerRegistryDnsZoneName
    name: containerRegistryPrivateEndpointName
    subnetName: privateEndpointSubnetName
    privateLinkServiceId: containerRegistry.id
    vNetName: vNetName
    location: location
  }
}

module proxyRoleAssignment '../roleassignments/roleassignment.bicep' = {
  name: 'proxy-roleAssignment'
  params: {
    principalId: managedIdentityProxy.properties.principalId
    roleName: 'AcrPull'
    targetResourceId: containerRegistry.id
    deploymentName: 'proxy-roleassignment-acrPull'
  }
}

module chatappRoleAssignment '../roleassignments/roleassignment.bicep' = {
  name: 'chatapp-roleAssignment'
  params: {
    principalId: managedIdentityChatapp.properties.principalId
    roleName: 'AcrPull'
    targetResourceId: containerRegistry.id
    deploymentName: 'chatapp-roleassignment-acrPull'
  }
}
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(workspaceId)) {
  name: 'registry-diagnostics'
  scope: containerRegistry
  properties: {
    workspaceId: workspaceId
    logs: [
      {
        category: 'ContainerRegistryRepositoryEvents'
        enabled: true
      }
      {
        category: 'ContainerRegistryLoginEvents'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
        timeGrain: 'PT1M'
      }
    ]
  }
}

output loginServer string = containerRegistry.properties.loginServer
output name string = containerRegistry.name
