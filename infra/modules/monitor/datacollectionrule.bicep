param name string
param location string = resourceGroup().location
param tags object = {}
param logAnalyticsWorkspaceResourceId string
param dataCollectionEndpointResourceId string
param proxyManagedIdentityName string


resource proxyIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: proxyManagedIdentityName
}

var uniqueDestinationName = uniqueString('Custom-OpenAIChargeback_CL')

resource dataCollectionRule 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  location: location
  name: name
  tags: union(tags, { 'azd-service-name': name })
  properties: {
    dataCollectionEndpointId: dataCollectionEndpointResourceId
    streamDeclarations: {
      'Custom-OpenAIChargeback_CL': {
        columns: [
            {
                name: 'TimeGenerated'
                type: 'datetime'
            }
            {
                name: 'Consumer'
                type: 'string'
            }
            {
                name: 'Model'
                type: 'string'
            }
            {
                name: 'ObjectType'
                type: 'string'
            }
            {
                name: 'InputTokens'
                type: 'int'
            }
            {
                name: 'OutputTokens'
                type: 'int'
            }
            {
                name: 'TotalTokens'
                type: 'int'
            }
        ]
      } 
    }
    destinations: {
      logAnalytics: [
        {
        workspaceResourceId: logAnalyticsWorkspaceResourceId
        name: uniqueDestinationName
        }
      ]
    }
    dataFlows: [
      {
        streams:[
          'Custom-OpenAIChargeback_CL'
        ]
        destinations: [
            uniqueDestinationName
        ]
        transformKql: 'source'
        outputStream: 'Custom-OpenAIChargeback_CL'
      }
    ]
  }
}

module roleAssignment '../roleassignments/roleassignment.bicep' = {
  name: 'roleAssignment'
  params: {
    principalId: proxyIdentity.properties.principalId
    roleName: 'Monitoring Metrics Publisher'
    targetResourceId: dataCollectionRule.id
    deploymentName: 'proxy-roleassignment-MonitoringMetricsPublisher'
  }
}

output dataCollectionRuleId string = dataCollectionRule.id
output dataCollectionRuleImmutableId string = dataCollectionRule.properties.immutableId
output dataCollectionRuleStreamName string = 'Custom-OpenAIChargeback_CL'
