param keyVaultName string
param functionKeySecretName string
param functionAppName string

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource functionApp 'Microsoft.Web/sites@2022-09-01' existing = {
  name: functionAppName
}

resource functionAppHost 'Microsoft.Web/sites/host@2022-09-01' existing = {
  name: 'default'
  parent: functionApp
}

resource functionKeyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: functionKeySecretName
  properties: {
    value: functionAppHost.listKeys().functionKeys.default
  }
}

output functionKeyVaultSecretName string = functionKeyVaultSecret.name
