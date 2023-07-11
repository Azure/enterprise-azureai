param keyVaultName string
param openaiApiKey string
param location string = resourceGroup().location
param tags object = {}
param principalId string

module keyVault './keyvault.bicep' = {
  name: 'keyvault'
  params: {
    name: keyVaultName
    location: location
    tags: tags
    principalId: principalId
  }
}

module keyVaultAccess './keyvault-access.bicep' = {
  name: 'keyvault-access'
  params: {
    keyVaultName: keyVault.outputs.name
  }
}

module keyVaultSecret './keyvault-secret.bicep' = {
  name: 'keyvault-secret'
  params: {
    keyVaultName: keyVault.outputs.name
    openaiApiKey: openaiApiKey
  }
}

output keyVaultName string = keyVault.outputs.name
output keyVaultSecretName string = keyVaultSecret.outputs.keyVaultSecretName
