param apimServiceName string
param proxyApiBackendId string
param proxyAppUri string
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
  name: proxyApiBackendId
  parent: apimService
  properties: {
    description: proxyApiBackendId
    url: proxyAppUri
    protocol: 'http'
    tls: {
      validateCertificateChain: true
      validateCertificateName: true
    }

  }
}

resource apimProxyApi 'Microsoft.ApiManagement/service/apis@2023-03-01-preview' = {
  name: 'ai-proxy'
  parent: apimService
  properties: {
    path: 'openai'
    apiRevision: '1'
    displayName: 'AI Proxy'
    format: 'openapi-link'
    protocols: [ 'https' ]
    value: 'https://raw.githubusercontent.com/Azure/azure-rest-api-specs/main/specification/cognitiveservices/data-plane/AzureOpenAI/inference/stable/2023-05-15/inference.json'
    subscriptionRequired: true
    subscriptionKeyParameterNames: {
      header: 'api-key'
    }
  }
}

resource openAiMarketingLimitedProduct 'Microsoft.ApiManagement/service/products@2022-08-01' = {
  parent: apimService
  name: 'openAiMarketingLimited'
  properties: {
    displayName: 'Marketing OpenAI Limited'
    description: 'Marketing team must subscribe for this Product to use the OpenAI API. They are limited to specific versions of the OpenAI API models. This is handled by Product specific Policies on APIM.'
    approvalRequired: false
    subscriptionRequired: true
    state: 'published'
  }
}

resource openAiMarketingLimitedProductPolicy 'Microsoft.ApiManagement/service/products/policies@2020-12-01' = {
  name: 'policy'
  parent: openAiMarketingLimitedProduct
  properties: {
    value: loadTextContent('./policies/product_policy_model_limit.xml')
    format: 'rawxml'
  }
}

resource openAiProductLink 'Microsoft.ApiManagement/service/products/apiLinks@2023-03-01-preview' = {
  name: 'openai-product-apilink'
  parent: openAiMarketingLimitedProduct
  properties: {
    apiId: apimProxyApi.id
  }
}

resource productSubscription 'Microsoft.ApiManagement/service/subscriptions@2021-04-01-preview' = {
  name: 'MarketingProductSubscription'
  parent: apimService
  properties: {
    displayName: 'Marketing OpenAI Product Subscription'
    scope: '/products/${openAiMarketingLimitedProduct.id}'
    state: 'active'
    allowTracing: true
  }
}


resource proxyApiPolicy 'Microsoft.ApiManagement/service/apis/policies@2023-03-01-preview' = {
  name: 'policy'
  parent: apimProxyApi
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
  parent: apimProxyApi
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
    