param name string
param location string = resourceGroup().location
param tags object = {}
param logAnalyticsWorkspaceId string
//Private Endpoint settings
param privateLinkScopeName string
param vNetName string
param privateEndpointSubnetName string
param dnsZoneName string
param privateEndpointName string
param wbName string = guid(resourceGroup().id, 'OpenAIWorkBook')
param qpName string = guid('Query Pack')
param wbSerializedData object

var kqlQuery = '''
requests
| where operation_Name == "azure-openai-service-api;rev=1 - Completions_Create" or operation_Name == "azure-openai-service-api;rev=1 - ChatCompletions_Create"
| extend Prompt = parse_json(tostring(parse_json(tostring(parse_json(tostring(customDimensions.["Request-Body"])).messages[-1].content))))
| extend Generation = parse_json(tostring(parse_json(tostring(parse_json(tostring(customDimensions.["Response-Body"])).choices))[0].message)).content
| extend promptTokens = parse_json(tostring(parse_json(tostring(customDimensions.["Response-Body"])).usage)).prompt_tokens
| extend completionTokens = parse_json(tostring(parse_json(tostring(customDimensions.["Response-Body"])).usage)).completion_tokens
| extend totalTokens = parse_json(tostring(parse_json(tostring(customDimensions.["Response-Body"])).usage)).total_tokens
| project timestamp, Prompt, Generation, promptTokens, completionTokens, totalTokens, round(duration,2), operation_Name
'''

resource privateLinkScope 'microsoft.insights/privateLinkScopes@2021-07-01-preview' existing = {
  name: privateLinkScopeName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspaceId
    publicNetworkAccessForIngestion: 'Disabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

resource queryPack 'Microsoft.OperationalInsights/queryPacks@2019-09-01' = {
  name: 'OpenAI Query Pack'
  location: location
  properties: {}
}

resource query 'Microsoft.OperationalInsights/queryPacks/queries@2019-09-01' = {
  parent: queryPack
  name: qpName
  properties: {
    displayName: 'OpenAI Logs'
    description: 'Requests and responses from OpenAI calls'
    body: kqlQuery
    related: {
      categories: [
        'applications'
      ]
      resourceTypes: [
        'microsoft.insights/components'
      ]
    }
    tags: {
      labels: [
        'playGround'
      ]
    }
  }
}

resource workbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: wbName
  location: location
  kind: 'shared'
  properties: {
    displayName: 'OpenAI WorkBook'
    serializedData: string(wbSerializedData)
    sourceId: applicationInsights.id
    category: 'OpenAI'
  }
}

module privateEndpoint '../networking/private-endpoint.bicep' = {
  name: '${applicationInsights.name}-privateEndpoint-deployment'
  params: {
    groupIds: [
      'azuremonitor'
    ]
    dnsZoneName: dnsZoneName
    name: privateEndpointName
    subnetName: privateEndpointSubnetName
    privateLinkServiceId: privateLinkScope.id
    vNetName: vNetName
    location: location
  }
}

resource appInsightsScopedResource 'Microsoft.Insights/privateLinkScopes/scopedResources@2021-07-01-preview' = {
  parent: privateLinkScope
  name: '${applicationInsights.name}-connection'
  properties: {
    linkedResourceId: applicationInsights.id
  }
}

output connectionString string = applicationInsights.properties.ConnectionString
output instrumentationKey string = applicationInsights.properties.InstrumentationKey
output name string = applicationInsights.name
