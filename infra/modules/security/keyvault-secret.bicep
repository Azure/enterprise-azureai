param keyVaultName string
param openAiKeySecretName string = ''
param functionKeySecretName string = ''
param openAiName string = ''
param functionAppName string = ''

resource keyVault 'Microsoft.KeyVault/vaults@2022-07-01' existing = {
  name: keyVaultName
}

resource account 'Microsoft.CognitiveServices/accounts@2023-05-01' existing = if (openAiName != '') {
  name: openAiName
}

resource functionApp 'Microsoft.Web/sites@2022-09-01' existing = if (functionAppName != '') {
  name: functionAppName
}

resource openAikeyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = if (openAiName != '') {
  parent: keyVault
  name: openAiKeySecretName
  properties: {
    value: account.listKeys().key1
  }
}

resource functionKeyVaultSecret 'Microsoft.KeyVault/vaults/secrets@2021-11-01-preview' = if (functionAppName != '') {
  parent: keyVault
  name: functionKeySecretName
  properties: {
    value: functionApp.listKeys().key1
  }
}

output openAiKeyVaultSecretName string = openAikeyVaultSecret.name
output functionKeyVaultSecretName string = functionKeyVaultSecret.name
