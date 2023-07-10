targetScope = 'resourceGroup'

param apimName string
param appInsightsName string

resource apiManagement 'Microsoft.ApiManagement/service@2020-12-01' existing = {
  name: apimName
}

resource apiManagementLogger 'Microsoft.ApiManagement/service/loggers@2020-12-01' existing = {
  name: '${apimName}/${appInsightsName}'
}

resource apimApi 'Microsoft.ApiManagement/service/apis@2020-12-01' = {
  name: 'httpbin-api'
  parent: apiManagement
  properties: {
    path: 'httpbin'
    serviceUrl: 'https://httpbin.org'
    apiRevision: '1'
    displayName: 'HttpBin API'
    description: 'API Management facade for a very handy and free online HTTP tool.'
    subscriptionRequired: false
    protocols: [
      'https'
    ]
  }
}

resource apiOperationGet 'Microsoft.ApiManagement/service/apis/operations@2020-06-01-preview' = {
  name: 'get'
  parent: apimApi
  properties: {
    displayName: '/get'
    method: 'GET'
    urlTemplate: '/get'
    description: 'Returns GET data.'
  }
}

resource apiAllPolicies 'Microsoft.ApiManagement/service/apis/policies@2020-12-01' = {
  name: 'policy'
  parent: apimApi
  properties: {
    value: loadTextContent('./policies/api_policy.xml')
    format: 'rawxml'
  }
}

resource apiGetPolicies 'Microsoft.ApiManagement/service/apis/operations/policies@2020-12-01' = {
  name: 'policy'
  parent: apiOperationGet
  properties: {
    value: loadTextContent('./policies/operation_policy.xml')
    format: 'rawxml'
  }
  dependsOn: [
    apiAllPolicies
  ]
}

resource apiMonitoring 'Microsoft.ApiManagement/service/apis/diagnostics@2020-06-01-preview' = {
  name: 'applicationinsights'
  parent: apimApi
  properties: {
    alwaysLog: 'allErrors'
    loggerId: apiManagementLogger.id  
    logClientIp: true
    httpCorrelationProtocol: 'W3C'
    verbosity: 'debug'
    operationNameFormat: 'Url'
  }
}
