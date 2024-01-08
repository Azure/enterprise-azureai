param targetResourceId string
param deploymentName string
param roleDefinitionId string
param principalId string
param principalType string = 'ServicePrincipal'

resource ResourceRoleAssignment 'Microsoft.Resources/deployments@2023-07-01' = {
  name: deploymentName
  properties: {
    mode: 'Incremental'
    template: json(loadTextContent('./roleassignmentARM.json'))
    parameters: {
      scope: {
        value: targetResourceId
      }
      roleDefinitionId: {
        value: roleDefinitionId
      }
      principalId: {
        value: principalId
      }
      principalType: {
        value: principalType
      }
      name: {
        value: guid(targetResourceId, principalId)
      }
    }
  }
}
