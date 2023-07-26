param keyVaultName string = ''
param secretName string
param openAiName string

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource account 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: openAiName
}

resource keyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: secretName
  properties: {
    value: account.listKeys().key1
  }
}

output keyVaultSecretName string = keyVaultSecret.name
