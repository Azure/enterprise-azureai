targetScope = 'resourceGroup'

param apimName string
param appInsightsName string
param logicAppName string
param serviceBusNamespaceName string
param serviceBusSubscriptionPath string
param serviceBusSendListenSigNamedValue string
param workflowGetName string
param workflowGetSigNamedValue string
param workflowPostName string
param workflowPostSigNamedValue string

var serviceBusUri = 'https://${serviceBusNamespaceName}.servicebus.windows.net'
var apiAllPolicy = '<policies><inbound><base /><set-header name="Ocp-Apim-Subscription-Key" exists-action="delete" /></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>'
var apiGetPolicy = '<policies><inbound><base /><set-backend-service backend-id="${logicAppName}" /><rewrite-uri template="${workflowGetName}/triggers/manual/invoke?api-version=2020-05-01-preview" /><set-query-parameter name="sig" exists-action="append"><value>{{${workflowGetSigNamedValue}}}</value></set-query-parameter></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>'
var apiCreatePolicy = '<policies><inbound><base /><set-backend-service backend-id="${logicAppName}" /><set-header name="operation" exists-action="append"><value>create</value></set-header><rewrite-uri template="${workflowPostName}/triggers/manual/invoke?api-version=2020-05-01-preview" /><set-query-parameter name="sig" exists-action="append"><value>{{${workflowPostSigNamedValue}}}</value></set-query-parameter></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>'
var apiUpdatePolicy = '<policies><inbound><base /><set-backend-service backend-id="${logicAppName}" /><set-header name="operation" exists-action="append"><value>update</value></set-header><rewrite-uri template="${workflowPostName}/triggers/manual/invoke?api-version=2020-05-01-preview" /><set-query-parameter name="sig" exists-action="append"><value>{{${workflowPostSigNamedValue}}}</value></set-query-parameter><set-method>POST</set-method></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>'
var apiDeletePolicy = '<policies><inbound><base /><set-backend-service backend-id="${logicAppName}" /><set-header name="operation" exists-action="append"><value>delete</value></set-header><rewrite-uri template="${workflowPostName}/triggers/manual/invoke?api-version=2020-05-01-preview" /><set-query-parameter name="sig" exists-action="append"><value>{{${workflowPostSigNamedValue}}}</value></set-query-parameter><set-method>POST</set-method></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>'
var apiGetUpdatesPolicy = '<policies><inbound><base /><set-backend-service backend-id="${serviceBusNamespaceName}" /><rewrite-uri template="${serviceBusSubscriptionPath}" /><set-header name="Authorization" exists-action="override"><value>{{${serviceBusSendListenSigNamedValue}}}</value></set-header><set-method>DELETE</set-method></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>'

resource apiManagement 'Microsoft.ApiManagement/service@2020-12-01' existing = {
  name: apimName
}

resource apiManagementLogger 'Microsoft.ApiManagement/service/loggers@2020-12-01' existing = {
  name: '${apimName}/${appInsightsName}'
}

resource logicApp 'Microsoft.Web/sites@2021-02-01' existing = {
  name: logicAppName
}

resource apimApi 'Microsoft.ApiManagement/service/apis@2020-12-01' = {
  name: 'customer-api'
  parent: apiManagement
  properties: {
    path: 'customer'
    apiRevision: '1'
    displayName: 'Customer API'
    subscriptionRequired: false
    protocols: [
      'https'
    ]
  }
}

resource logicAppBackend 'Microsoft.ApiManagement/service/backends@2021-08-01' = {
  name: logicAppName
  parent: apiManagement
  properties: {
    description: logicAppName
    url: 'https://${logicApp.properties.defaultHostName}/api'
    protocol: 'http'
    credentials: {
      query: {
        sp: [
          '%2Ftriggers%2Fmanual%2Frun'
        ]
        sv: [
          '1.0'
        ]
      }
      header: {}
    }
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}

resource serviceBusBackend 'Microsoft.ApiManagement/service/backends@2021-08-01' = {
  name: serviceBusNamespaceName
  parent: apiManagement
  properties: {
    description: serviceBusNamespaceName
    url: serviceBusUri
    protocol: 'http'
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
}

resource apiOperationGet 'Microsoft.ApiManagement/service/apis/operations@2020-06-01-preview' = {
  name: 'get'
  parent: apimApi
  properties: {
    displayName: 'Get Customer'
    method: 'GET'
    urlTemplate: '/get'
    description: 'Get Customer data'
    request: {
      description: 'Get Customer'
      queryParameters: [
        {
          name: 'id'
          description: 'Filter on Customer Id'
          required: false
          type: 'Integer'
        }
      ]
    }
  }
}

resource apiOperationCreate 'Microsoft.ApiManagement/service/apis/operations@2020-06-01-preview' = {
  name: 'create'
  parent: apimApi
  properties: {
    displayName: 'Create Customer'
    method: 'POST'
    urlTemplate: '/create'
    description: 'Create a customer'
    request: {
      representations: [
          {
              contentType: 'application/json' 
              schemaId: 'customer'
              typeName: 'Customer'
          }
      ]
    }
  }
  dependsOn: [
    customerSchema
  ]
}

resource apiOperationDelete 'Microsoft.ApiManagement/service/apis/operations@2020-06-01-preview' = {
  name: 'delete'
  parent: apimApi
  properties: {
    displayName: 'Delete Customer'
    method: 'DELETE'
    urlTemplate: '/delete'
    description: 'Delete a customer'
    request: {
      representations: [
          {
              contentType: 'application/json'
              schemaId: 'customer'
              typeName: 'Customer'
          }
      ]
    }
  }
  dependsOn: [
    customerSchema
  ]
}

resource apiOperationUpdate 'Microsoft.ApiManagement/service/apis/operations@2020-06-01-preview' = {
  name: 'update'
  parent: apimApi
  properties: {
    displayName: 'Update Customer'
    method: 'PATCH'
    urlTemplate: '/update'
    description: 'Update a customer'
    request: {
      representations: [
          {
              contentType: 'application/json'
              schemaId: 'customer'
              typeName: 'Customer'
          }
      ]
    }
  }
  dependsOn: [
    customerSchema
  ]
}

resource apiOperationGetUpdates 'Microsoft.ApiManagement/service/apis/operations@2020-06-01-preview' = {
  name: 'get-updates'
  parent: apimApi
  properties: {
    displayName: 'Get Customer Updates'
    method: 'GET'
    urlTemplate: '/get-updates'
    description: 'Get customer updates'
  }
}

resource apiAllPolicies 'Microsoft.ApiManagement/service/apis/policies@2020-12-01' = {
  name: 'policy'
  parent: apimApi
  properties: {
    value: apiAllPolicy
    format: 'rawxml'
  }
  dependsOn: [
    logicAppBackend
  ]
}

resource apiGetPolicies 'Microsoft.ApiManagement/service/apis/operations/policies@2020-12-01' = {
  name: 'policy'
  parent: apiOperationGet
  properties: {
    value: apiGetPolicy
    format: 'rawxml'
  }
  dependsOn: [
    logicAppBackend
    apiAllPolicies
  ]
}

resource apiCreatePolicies 'Microsoft.ApiManagement/service/apis/operations/policies@2020-12-01' = {
  name: 'policy'
  parent: apiOperationCreate
  properties: {
    value: apiCreatePolicy
    format: 'rawxml'
  }
  dependsOn: [
    logicAppBackend
    apiAllPolicies
  ]
}

resource apiUpdatePolicies 'Microsoft.ApiManagement/service/apis/operations/policies@2020-12-01' = {
  name: 'policy'
  parent: apiOperationUpdate
  properties: {
    value: apiUpdatePolicy
    format: 'rawxml'
  }
  dependsOn: [
    logicAppBackend
    apiAllPolicies
  ]
}

resource apiDeletePolicies 'Microsoft.ApiManagement/service/apis/operations/policies@2020-12-01' = {
  name: 'policy'
  parent: apiOperationDelete
  properties: {
    value: apiDeletePolicy
    format: 'rawxml'
  }
  dependsOn: [
    logicAppBackend
    apiAllPolicies
  ]
}

resource apiGetUpdatesPolicies 'Microsoft.ApiManagement/service/apis/operations/policies@2020-12-01' = {
  name: 'policy'
  parent: apiOperationGetUpdates
  properties: {
    value: apiGetUpdatesPolicy
    format: 'rawxml'
  }
  dependsOn: [
    logicAppBackend
    apiAllPolicies
  ]
}

resource customerSchema 'Microsoft.ApiManagement/service/apis/schemas@2020-06-01-preview' = {
  name: 'customer'
  parent: apimApi
  properties: {
    contentType: 'application/vnd.oai.openapi.components+json'
    document: {
      components: {
        schemas: {
          Customer: {
            type: 'object'
            properties: {
                id: {
                    type: 'integer'
                }
                firstName: {
                    type: 'string'
                }
                lastName: {
                    type: 'string'
                }
                status: {
                    type: 'integer'
                }
            }
          }
        }
      }
    }
  }
}

resource apiMonitoring 'Microsoft.ApiManagement/service/apis/diagnostics@2020-06-01-preview' = {
  name: 'applicationinsights'
  parent: apimApi
  properties: {
    alwaysLog: 'allErrors'
    loggerId: apiManagementLogger.id  
    logClientIp: true
    httpCorrelationProtocol: 'W3C'
    verbosity: 'verbose'
    operationNameFormat: 'Url'
  }
}
