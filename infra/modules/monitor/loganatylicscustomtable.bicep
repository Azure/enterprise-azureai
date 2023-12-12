param logAnalyticsWorkspaceName string


resource azureOpenAIChargebackTable 'Microsoft.OperationalInsights/workspaces/tables@2022-10-01' = {
  name: '${logAnalyticsWorkspaceName}/OpenAIChargeback_CL'
  properties: {
    totalRetentionInDays: 90
    retentionInDays: 90
    plan: 'Analytics'
    schema: {
      name: 'OpenAIChargeback_CL'
      description:'Custom Log Analytics table for OpenAI Chargeback data'
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
}
