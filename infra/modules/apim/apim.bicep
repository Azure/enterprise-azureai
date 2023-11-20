param name string
param location string = resourceGroup().location
param tags object = {}

@minLength(1)
param publisherEmail string = 'noreply@microsoft.com'

@minLength(1)
param publisherName string = 'n/a'
param sku string
param skuCount int = 1
param applicationInsightsName string
param logAnalyticsWorkspaceId string // optional for Diagnostic Settings
param openAiUri string
param functionAppUri string
param openaiKeyVaultSecretName string
param functionKeyVaultSecretName string
param keyVaultEndpoint string
param apimManagedIdentityName string
param redisCacheServiceName string = ''
//Vnet Integration
param apimSubnetId string
param virtualNetworkType string
param eventHubNamespaceName string
param eventHubName string

@description('The number of bytes of the request/response body to record for diagnostic purposes')
param logBytes int = 8192

var openAiApiBackendId = 'openai-backend'
var funcApiBackendId = 'function-backend'
var openAiApiKeyNamedValue = 'openai-apikey'
var functionKeyNamedValue = 'function-key'
var eventHubEndpoint = '${eventHubNamespaceName}.servicebus.windows.net'
var diagnosticsNameOpenAi = 'diag-openai'
var diagnosticsNameFunc = 'diag-func'

var logSettings = {
  headers: [ 'Content-type', 'User-agent' ]
  body: { bytes: logBytes }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

resource managedIdentityApim 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: apimManagedIdentityName
}

resource redisCache 'Microsoft.Cache/redis@2022-06-01' existing = if (!empty(redisCacheServiceName)) {
  name: redisCacheServiceName
}

resource apimService 'Microsoft.ApiManagement/service@2023-03-01-preview' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  sku: {
    name: sku
    capacity: (sku == 'Consumption') ? 0 : ((sku == 'Developer') ? 1 : skuCount)
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityApim.id}': {}
    }
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    virtualNetworkType: virtualNetworkType
    virtualNetworkConfiguration: {
      subnetResourceId: apimSubnetId
    }
    // Custom properties are not supported for Consumption SKU
    customProperties: sku == 'Consumption' ? {} : {
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_GCM_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_256_CBC_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_CBC_SHA256': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_256_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TLS_RSA_WITH_AES_128_CBC_SHA': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Ciphers.TripleDes168': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Protocols.Ssl30': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls10': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Tls11': 'false'
      'Microsoft.WindowsAzure.ApiManagement.Gateway.Security.Backend.Protocols.Ssl30': 'false'
    }
  }
}

resource apimOpenaiApi 'Microsoft.ApiManagement/service/apis@2023-03-01-preview' = {
  name: 'azure-openai-service-api'
  parent: apimService
  properties: {
    path: 'openai'
    apiRevision: '1'
    displayName: 'Azure OpenAI Service API'
    format: 'openapi-link'
    protocols: [ 'https' ]
    value: 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/2023-05-15/inference.json'
    subscriptionRequired: true
  }
}

resource apimFuncApi 'Microsoft.ApiManagement/service/apis@2023-03-01-preview' = {
  name: 'azure-func-api'
  parent: apimService
  properties: {
    path: 'ai'
    apiRevision: '1'
    displayName: 'Azure AI Function API'
    format: 'openapi-link'
    protocols: [ 'https' ]
    value: 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/2023-05-15/inference.json'
    subscriptionRequired: true
  }
}

resource openAiBackend 'Microsoft.ApiManagement/service/backends@2023-03-01-preview' = {
  name: openAiApiBackendId
  parent: apimService
  properties: {
    description: openAiApiBackendId
    url: openAiUri
    protocol: 'http'
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
    credentials: {
      header: {
        'api-key': [
          '{{${openAiApiKeyNamedValue}}}'
        ]
      }
    }
  }
}

resource funcBackend 'Microsoft.ApiManagement/service/backends@2023-03-01-preview' = {
  name: funcApiBackendId
  parent: apimService
  properties: {
    description: funcApiBackendId
    url: 'https://${functionAppUri}/openai/'
    protocol: 'http'
    credentials: {
      header: {
        'x-functions-key': [
          '{{${functionKeyNamedValue}}}'
        ]
      }
    }
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }
  }
  dependsOn: [
    funcKeyNamedValue
  ]
}

resource apimOpenaiApiKeyNamedValue 'Microsoft.ApiManagement/service/namedValues@2022-08-01' = {
  name: openAiApiKeyNamedValue
  parent: apimService
  properties: {
    displayName: openAiApiKeyNamedValue
    secret: true
    keyVault:{
      secretIdentifier: '${keyVaultEndpoint}secrets/${openaiKeyVaultSecretName}'
      identityClientId: apimService.identity.userAssignedIdentities[managedIdentityApim.id].clientId
    }
  }
}

resource funcKeyNamedValue 'Microsoft.ApiManagement/service/namedValues@2022-08-01' = {
  name: functionKeyNamedValue
  parent: apimService
  properties: {
    displayName: functionKeyNamedValue
    secret: true
    keyVault:{
      secretIdentifier: '${keyVaultEndpoint}secrets/${functionKeyVaultSecretName}'
      identityClientId: apimService.identity.userAssignedIdentities[managedIdentityApim.id].clientId
    }
  }
}

resource openaiApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-03-01-preview' = {
  name: 'policy'
  parent: apimOpenaiApi
  properties: {
    value: loadTextContent('./policies/api_policy_openai.xml')
    format: 'rawxml'
  }
  dependsOn: [
    openAiBackend
    eventHubLogger
  ]
}

resource funcApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-03-01-preview' = {
  name: 'policy'
  parent: apimFuncApi
  properties: {
    value: loadTextContent('./policies/api_policy_func.xml')
    format: 'rawxml'
  }
  dependsOn: [
    funcBackend
  ]
}

resource apiSubscription 'Microsoft.ApiManagement/service/subscriptions@2023-03-01-preview' = {
  parent: apimService
  name: 'openai-subscription'
  properties: {
    scope: '/apis'
    displayName: 'OpenAI Subscription'
    state: 'active'
    allowTracing: true
  }
}

resource apimCache 'Microsoft.ApiManagement/service/caches@2023-03-01-preview' = if (!empty(redisCacheServiceName)) {
  name: 'redis-cache'
  parent: apimService
  properties: {
    connectionString: '${redisCache.properties.hostName},password=${redisCache.listKeys().primaryKey},ssl=True,abortConnect=False'
    useFromLocation: 'default'
    description: redisCache.properties.hostName
  }
}

resource apimLogger 'Microsoft.ApiManagement/service/loggers@2021-12-01-preview' = {
  name: 'appinsights-logger'
  parent: apimService
  properties: {
    credentials: {
      instrumentationKey: applicationInsights.properties.InstrumentationKey
    }
    description: 'Logger to Azure Application Insights'
    isBuffered: false
    loggerType: 'applicationInsights'
    resourceId: applicationInsights.id
  }
}

resource eventHubLogger 'Microsoft.ApiManagement/service/loggers@2023-03-01-preview' = {
  name: 'eventhub-logger'
  parent: apimService
  properties: {
    loggerType: 'azureEventHub'
    description: 'Event hub logger with user-assigned managed identity'
    credentials: {
      endpointAddress: eventHubEndpoint
      identityClientId: managedIdentityApim.properties.clientId
      name: eventHubName
    }
  }
}
/*
resource diagnosticsPolicyOpenAi 'Microsoft.ApiManagement/service/apis/diagnostics@2022-08-01' = {
  name: diagnosticsNameOpenAi
  parent: apimOpenaiApi
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

resource diagnosticsPolicyFunc 'Microsoft.ApiManagement/service/apis/diagnostics@2022-08-01' = {
  name: diagnosticsNameFunc
  parent: apimFuncApi
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
*/
output apimName string = apimService.name
output apimOpenaiApiPath string = apimOpenaiApi.properties.path
