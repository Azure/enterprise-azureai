param name string
param location string = resourceGroup().location
param tags object = {}
param logAnalyticsWorkspaceId string
param dataCollectionEndpointResourceId string

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
        workspaceResourceId: logAnalyticsWorkspaceId
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

output dataCollectionRuleId string = dataCollectionRule.id
output dataCollectionRuleImmutableId string = dataCollectionRule.properties.immutableId
