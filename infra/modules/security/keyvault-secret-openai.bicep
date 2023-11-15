param keyVaultName string
param openAiKeySecretName string
param openAiName string

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource account 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = {
  name: openAiName
}

resource openAikeyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = {
  parent: keyVault
  name: openAiKeySecretName
  properties: {
    value: account.listKeys().key1
  }
}

output openAiKeyVaultSecretName string = openAikeyVaultSecret.name
