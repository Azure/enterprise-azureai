param name string = 'add'
param apimName string = ''
param keyVaultName string = ''
param permissions object = { secrets: [ 'get', 'list' ] }

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource apim 'Microsoft.ApiManagement/service@2021-04-01-preview' existing = {
  name: apimName
}

resource keyVaultAccessPolicies 'Microsoft.KeyVault/vaults/accessPolicies@2022-07-01' = {
  parent: keyVault
  name: name
  properties: {
    accessPolicies: [ {
        objectId: apim.identity.principalId
        tenantId: subscription().tenantId
        permissions: permissions
      } ]
  }
}
