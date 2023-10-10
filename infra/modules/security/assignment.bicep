param name string
param location string = resourceGroup().location
param tags object = {}

param policyAssignmentName string = 'audit-cogs-disable-public-access'
param policyDefinitionID string = '/providers/Microsoft.Authorization/policyDefinitions/0725b4dd-7e76-479c-a735-68e7ee23d5ca'

resource assignment 'Microsoft.Authorization/policyAssignments@2021-09-01' = {
    name: policyAssignmentName
    scope: subscriptionResourceId('Microsoft.Resources/resourceGroups', resourceGroup().name)
    tags: union(tags, { 'azd-service-name': name })
    properties: {
        policyDefinitionId: policyDefinitionID
    }
}

output assignmentId string = assignment.id
