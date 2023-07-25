param keyVaultName string = ''
@secure()
param secret string
param secretName string

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource keyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: secretName
  properties: {
    value: secret
  }
}

output keyVaultSecretName string = keyVaultSecret.name
