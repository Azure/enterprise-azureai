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
param qpName string = guid('Query Pack')

var kqlQuery = '''
ApiManagementGatewayLogs
| where OperationId == 'completions_create'
| extend modelkey = substring(parse_json(BackendResponseBody)['model'], 0, indexof(parse_json(BackendResponseBody)['model'], '-', 0, -1, 2))
| extend model = tostring(parse_json(BackendResponseBody)['model'])
| extend prompttokens = parse_json(parse_json(BackendResponseBody)['usage'])['prompt_tokens']
| extend completiontokens = parse_json(parse_json(BackendResponseBody)['usage'])['completion_tokens']
| extend totaltokens = parse_json(parse_json(BackendResponseBody)['usage'])['total_tokens']
| extend ip = CallerIpAddress
| summarize
    sum(todecimal(prompttokens)),
    sum(todecimal(completiontokens)),
    sum(todecimal(totaltokens)),
    avg(todecimal(totaltokens))
    by ip, model
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
