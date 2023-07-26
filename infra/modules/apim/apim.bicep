param name string
param location string = resourceGroup().location
param tags object = {}

@minLength(1)
param publisherEmail string = 'noreply@microsoft.com'

@minLength(1)
param publisherName string = 'n/a'
param sku string = 'Developer'
param skuCount int = 1
param applicationInsightsName string
param openAiUri string
param openaiKeyVaultSecretName string
param keyVaultEndpoint string
param managedIdentityName string
param apimSubnetId string

var openAiApiKeyNamedValue = 'openai-apikey'
var openAiApiBackendId = 'openai-backend'

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: managedIdentityName
}

resource apimService 'Microsoft.ApiManagement/service@2021-08-01' = {
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
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    publisherEmail: publisherEmail
    publisherName: publisherName
    virtualNetworkType: 'External'
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

resource apimOpenaiApi 'Microsoft.ApiManagement/service/apis@2022-08-01' = {
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

resource openAiBackend 'Microsoft.ApiManagement/service/backends@2021-08-01' = {
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

resource apimOpenaiApiKeyNamedValue 'Microsoft.ApiManagement/service/namedValues@2022-08-01' = {
  name: openAiApiKeyNamedValue
  parent: apimService
  properties: {
    displayName: openAiApiKeyNamedValue
    secret: true
    keyVault:{
      secretIdentifier: '${keyVaultEndpoint}secrets/${openaiKeyVaultSecretName}'
      identityClientId: apimService.identity.userAssignedIdentities[managedIdentity.id].clientId
    }
  }
}

resource openaiApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2022-08-01' = {
  name: 'policy'
  parent: apimOpenaiApi
  properties: {
    value: loadTextContent('./policies/api_policy.xml')
    format: 'rawxml'
  }
  dependsOn: [
    openAiBackend
    apimOpenaiApiKeyNamedValue
  ]
}

resource apiOperationCompletions 'Microsoft.ApiManagement/service/apis/operations@2020-06-01-preview' existing = {
  name: 'ChatCompletions_Create'
  parent: apimOpenaiApi
}

resource chatCompletionsCreatePolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2022-08-01' = {
  name: 'policy'
  parent: apiOperationCompletions
  properties: {
    value: loadTextContent('./policies/api_operation_policy.xml')
    format: 'rawxml'
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

output apimName string = apimService.name
output apimOpenaiApiPath string = apimOpenaiApi.properties.path
