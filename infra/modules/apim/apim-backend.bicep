param apimServiceName string
param chargeBackApiBackendId string
param chargeBackAppUri string
param logBytes int = 8192

var logSettings = {
  headers: [ 'Content-type', 'User-agent' ]
  body: { bytes: logBytes }
}

resource apimService 'Microsoft.ApiManagement/service@2023-03-01-preview' existing = {
  name: apimServiceName
}

resource apimLogger 'Microsoft.ApiManagement/service/loggers@2021-12-01-preview' existing = {
  name: 'appinsights-logger'
  parent: apimService
}

resource backend 'Microsoft.ApiManagement/service/backends@2023-03-01-preview' = {
  name: chargeBackApiBackendId
  parent: apimService
  properties: {
    description: chargeBackApiBackendId
    url: chargeBackAppUri
    protocol: 'http'
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }

  }
}

resource apimChargeBackApi 'Microsoft.ApiManagement/service/apis@2023-03-01-preview' = {
  name: 'chargeback-proxy'
  parent: apimService
  properties: {
    path: 'openai'
    apiRevision: '1'
    displayName: 'OpenAI Chargeback Proxy'
    format: 'openapi-link'
    protocols: [ 'https' ]
    value: 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/2023-05-15/inference.json'
    subscriptionRequired: true
    subscriptionKeyParameterNames: {
      header: 'api-key'
    }
  }
}

resource chargeBackApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-03-01-preview' = {
  name: 'policy'
  parent: apimChargeBackApi
  properties: {
    value: loadTextContent('./policies/api_policy_chargeback.xml')
    format: 'rawxml'
  }
  dependsOn: [
    backend
  ]
}

resource diagnosticsPolicy 'Microsoft.ApiManagement/service/apis/diagnostics@2022-08-01' = if (!empty(apimLogger.name)) {
  name: 'applicationinsights'
  parent: apimChargeBackApi
  properties: {
    alwaysLog: 'allErrors'
    httpCorrelationProtocol: 'W3C'
    logClientIp: true
    loggerId: apimLogger.id
    metrics: true
    verbosity: 'verbose'
    sampling: {
      samplingType: 'fixed'
      percentage: 100
    }
    frontend: {
      request: logSettings
      response: logSettings
    }
    backend: {
      request: logSettings
      response: logSettings
    }
  }
}
    