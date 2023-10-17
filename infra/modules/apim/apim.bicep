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
param openAiUri string
param apimManagedIdentityName string
param eventHubNamespaceName string
param eventHubName string
param redisCacheServiceName string = ''
//Vnet Integration
//param apimSubnetId string
param virtualNetworkType string = ''

var openAiApiBackendId = 'openai-backend'
var eventHubEndpoint = '${eventHubNamespaceName}.servicebus.windows.net'

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
    //virtualNetworkConfiguration: {
    //  subnetResourceId: apimSubnetId
    //}
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
    subscriptionRequired: true
    format: 'openapi+json'
    value: loadJsonContent('./openapi/openai-openapiv3.json')
    protocols: [
      'https'
    ]
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
  }
}

resource openaiApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-03-01-preview' = {
  name: 'policy'
  parent: apimOpenaiApi
  properties: {
    value: loadTextContent('./policies/api_policy.xml')
    format: 'rawxml'
  }
  dependsOn: [
    openAiBackend
  ]
}

resource apiOperationCompletions 'Microsoft.ApiManagement/service/apis/operations@2023-03-01-preview' existing = {
  name: 'ChatCompletions_Create'
  parent: apimOpenaiApi
}

resource chatCompletionsCreatePolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2023-03-01-preview' = {
  name: 'policy'
  parent: apiOperationCompletions
  properties: {
    value: loadTextContent('./policies/api_operation_policy.xml')
    format: 'rawxml'
  }
  dependsOn: [
    eventHubLogger
  ]
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

output apimName string = apimService.name
output apimOpenaiApiPath string = apimOpenaiApi.properties.path
