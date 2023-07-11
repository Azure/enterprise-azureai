param keyVaultName string = ''
@secure()
param openaiApiKey string

var secretName = 'openai-apikey'

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: secretName
  properties: {
    value: openaiApiKey
  }
}

output keyVaultSecretName string = secret.name
