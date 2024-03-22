param name string
param location string
param vNetName string
param privateEndpointSubnetName string
param cosmosPrivateEndpointName string
param cosmosAccountPrivateDnsZoneName string
param chatAppIdentityName string
param myIpAddress string = ''
param myPrincipalId string = ''
param dnsResourceGroupName string
param vnetResourceGroupName string

var defaultConsistencyLevel = 'Session'

resource chatAppIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: chatAppIdentityName
}

resource account 'Microsoft.DocumentDB/databaseAccounts@2022-05-15' = {
  name: toLower(name)
  kind: 'GlobalDocumentDB'
  location: location
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: defaultConsistencyLevel
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: true
      }
    ]
    disableKeyBasedMetadataWriteAccess: true
    databaseAccountOfferType: 'Standard'
    enableAutomaticFailover: false
    enableMultipleWriteLocations: false
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    publicNetworkAccess: 'Enabled' //to be able to run azurechat app locally
    ipRules: [
      {
        ipAddressOrRange: myIpAddress
      }
    ]

  }
}

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2022-05-15' = {
  name: 'chat'
  parent: account
  properties:{
    resource: {
      id: 'chat'
    }
  }
}

resource container 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2022-05-15' = {
  name: 'history'
  parent: database
  properties:{
    resource: {
      id: 'history'
      partitionKey: {
        paths: [
          '/userId'
        ]
        kind: 'Hash'
      }
    }
  }
}

var CosmosDBBuiltInDataContributor = {
  id: '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.DocumentDB/databaseAccounts/${account.name}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002'
}
resource sqlRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2023-11-15' = {
  name: guid(account.name, CosmosDBBuiltInDataContributor.id, chatAppIdentityName)
  parent: account
  properties: {
    principalId: chatAppIdentity.properties.principalId
    roleDefinitionId: CosmosDBBuiltInDataContributor.id
    scope: account.id
  }
}
resource sqlRoleAssignmentCurrentUser 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2023-11-15' = {
  name: guid(account.name,CosmosDBBuiltInDataContributor.id, myPrincipalId)
  parent: account
  properties: {
    principalId: myPrincipalId
    roleDefinitionId: CosmosDBBuiltInDataContributor.id
    scope: account.id
  }
}

module privateEndpoint '../networking/private-endpoint.bicep' = {
  name: '${account.name}-privateEndpoint-deployment'
  params: {
    groupIds: [
      'Sql'
    ]
    dnsZoneName: cosmosAccountPrivateDnsZoneName
    name: cosmosPrivateEndpointName
    subnetName: privateEndpointSubnetName
    privateLinkServiceId: account.id
    vNetName: vNetName
    location: location
    dnsResourceGroupName : dnsResourceGroupName
    vnetResourceGroupName: vnetResourceGroupName
  }
}

output cosmosDbEndPoint string = account.properties.documentEndpoint
