param name string
param location string = resourceGroup().location
param tags object = {}

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  properties: {
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    sku: { family: 'A', name: 'standard' }
  }
}

output endpoint string = keyVault.properties.vaultUri
output name string = keyVault.name
output id string = keyVault.id
