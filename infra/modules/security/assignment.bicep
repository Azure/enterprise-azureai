param name string = 'audit-cogs-disable-public-access'
param definitionId string = '/providers/Microsoft.Authorization/policyDefinitions/0725b4dd-7e76-479c-a735-68e7ee23d5ca'
param tags object = {}

resource assignment 'Microsoft.Authorization/policyAssignments@2021-09-01' = {
    name: name
    tags: union(tags, { 'azd-service-name': name })
    properties: {
        policyDefinitionId: definitionId
    }
}

output assignmentId string = assignment.id
