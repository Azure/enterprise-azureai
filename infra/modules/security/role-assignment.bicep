param name string
param userIdentityPrincipalId string
param keyVaultSecretsUserRoleDefinitionId string

resource kvRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: name
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', keyVaultSecretsUserRoleDefinitionId)
    principalId: userIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}
