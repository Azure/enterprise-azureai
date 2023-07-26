param name string
param location string
param logAnalyticsWorkspaceName string
param managedIdentityName string
param keyVaultPrivateEndpointName string
param vNetName string
param privateEndpointSubnetName string
param keyVaultDnsZoneName string
param publicNetworkAccess string = 'Disabled'
param tags object = {}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: managedIdentityName
}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: false
    enabledForTemplateDeployment: true
    publicNetworkAccess: publicNetworkAccess
    accessPolicies: [
      {
        objectId: managedIdentity.properties.principalId
        tenantId: managedIdentity.properties.tenantId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
}

module privateEndpoint '../networking/private-endpoint.bicep' = {
  name: '${keyVault.name}-privateEndpoint-deployment'
  params: {
    groupIds: [
      'vault'
    ]
    dnsZoneName: keyVaultDnsZoneName
    name: keyVaultPrivateEndpointName
    subnetName: privateEndpointSubnetName
    privateLinkServiceId: keyVault.id
    vNetName: vNetName
    location: location
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticsettings@2017-05-01-preview' = {
  name: 'Logging'
  scope: keyVault
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
      }
      {
        category: 'AzurePolicyEvaluationDetails'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output keyVaultName string = keyVault.name
output keyVaultResourceId string = keyVault.id
output keyVaultEndpoint string = keyVault.properties.vaultUri
