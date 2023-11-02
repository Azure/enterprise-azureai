param name string
param location string = resourceGroup().location
param tags object = {}
param appServicePlanName string
param managedIdentityName string
param logAnalyticsWorkspaceName string
param appInsightsName string
param storageAccountName string
//Vnet Integration & Private Endpoint settings
param functionAppPrivateEndpointName string
param appServicePrivateDnsZoneName string
param vNetName string
param privateEndpointSubnetName string
param appServiceSubnetName string
param openAiUri string
param functionContentShareName string

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: storageAccountName
}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2021-09-30-preview' existing = {
  name: managedIdentityName
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: appInsightsName
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2021-06-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource appServicePlan 'Microsoft.Web/serverfarms@2021-03-01' existing = {
  name: appServicePlanName
}
//Vnet Integration
resource appServiceSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-09-01' existing = {
  name: '${vNetName}/${appServiceSubnetName}'
}

resource functionApp 'Microsoft.Web/sites@2021-02-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': 'api' })
  kind: 'functionapp'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    serverFarmId: appServicePlan.id
    keyVaultReferenceIdentity: managedIdentity.id
    httpsOnly: true
    virtualNetworkSubnetId: appServiceSubnet.id
    siteConfig: {
      pythonVersion: '3.9'
      linuxFxVersion: 'python|3.9'
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: functionContentShareName
        }
        {
          name: 'WEBSITE_VNET_ROUTE_ALL'
          value: '1'
        }
        {
          name: 'WEBSITE_CONTENTOVERVNET'
          value: '1'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_Mode'
          value: 'Recommended'
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT' 
          value: 'true'
          }
        {
          name: 'ENABLE_ORYX_BUILD'  
          value: 'true'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'OpenAiUri'
          value: openAiUri
        }
      ]
    }
  }
}

//Private Endpoint
module functionAppPrivateEndpoint '../networking/private-endpoint.bicep' = {
  name: '${functionApp.name}-privateEndpoint-deployment'
  params: {
    groupIds: [
      'sites'
    ]
    dnsZoneName: appServicePrivateDnsZoneName
    name: functionAppPrivateEndpointName
    subnetName: privateEndpointSubnetName
    privateLinkServiceId: functionApp.id
    vNetName: vNetName
    location: location
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticsettings@2017-05-01-preview' = {
  name: 'Logging'
  scope: functionApp
  properties: {
    workspaceId: logAnalyticsWorkspace.id
    logs: [
      {
        category: 'FunctionAppLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

output functionAppName string = functionApp.name
output functionAppUri string = functionApp.properties.defaultHostName
