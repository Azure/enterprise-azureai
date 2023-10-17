param name string
param location string = resourceGroup().location
param tags object = {}
param appServicePlanName string
param managedIdentityName string
param logAnalyticsWorkspaceName string
param appInsightsName string
param functionAppStorageAccountName string
//Vnet Integration & Private Endpoint settings
//param functionAppPrivateEndpointName string
//param appServicePrivateDnsZoneName string
//param vNetName string
//param privateEndpointSubnetName string
//param appServiceSubnetName string
param eventHubNamespaceName string = ''
param eventHubName string = ''
param eventHubListenPolicyName string = ''
param kind string = 'functionapp,linux'
param allowedOrigins array = []
param alwaysOn bool = true
param appCommandLine string = ''
param clientAffinityEnabled bool = false
param enableOryxBuild bool = contains(kind, 'linux')
param functionAppScaleLimit int = -1
param linuxFxVersion string = runtimeNameAndVersion
param minimumElasticInstanceCount int = -1
param numberOfWorkers int = -1
param scmDoBuildDuringDeployment bool = true
param use32BitWorkerProcess bool = false
param ftpsState string = 'FtpsOnly'
// Runtime Properties
@allowed([
  'dotnet', 'dotnetcore', 'dotnet-isolated', 'node', 'python', 'java', 'powershell', 'custom'
])
param runtimeName string
param runtimeNameAndVersion string = '${runtimeName}|${runtimeVersion}'
param runtimeVersion string

resource functionAppStorageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' existing = {
  name: functionAppStorageAccountName
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
/*
resource appServiceSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-09-01' existing = {
  name: '${vNetName}/${appServiceSubnetName}'
}
*/
resource rule 'Microsoft.EventHub/namespaces/eventhubs/authorizationRules@2022-01-01-preview' existing = if (!empty(eventHubNamespaceName)) {
  name: '${eventHubNamespaceName}/${eventHubName}/${eventHubListenPolicyName}'
}

resource functionApp 'Microsoft.Web/sites@2021-02-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': 'api' })
  kind: kind
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
    clientAffinityEnabled: clientAffinityEnabled
    //virtualNetworkSubnetId: appServiceSubnet.id
    siteConfig: {
      powerShellVersion: '7.2'
      linuxFxVersion: linuxFxVersion
      alwaysOn: alwaysOn
      ftpsState: ftpsState
      appCommandLine: appCommandLine
      numberOfWorkers: numberOfWorkers != -1 ? numberOfWorkers : null
      minimumElasticInstanceCount: minimumElasticInstanceCount != -1 ? minimumElasticInstanceCount : null
      use32BitWorkerProcess: use32BitWorkerProcess
      functionAppScaleLimit: functionAppScaleLimit != -1 ? functionAppScaleLimit : null
      cors: {
        allowedOrigins: union([ 'https://portal.azure.com', 'https://ms.portal.azure.com' ], allowedOrigins)
      }
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
          name: 'ApplicationInsightsAgent_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'XDT_MicrosoftApplicationInsights_Mode'
          value: 'Recommended'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionAppStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${functionAppStorageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionAppStorageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${functionAppStorageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'powershell'
        }
        {
          name: 'WEBSITE_RUN_FROM_PACKAGE'
          value: '1'
        }
        {
          name: 'EVENTHUB_CONNECTION_STRING'
          value: rule.listkeys().primaryConnectionString
        }
        {
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: string(scmDoBuildDuringDeployment)
        }
        {
          name: 'ENABLE_ORYX_BUILD'
          value: string(enableOryxBuild)
        }
      ]
    }
  }
}

//Private Endpoint
/*
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
*/
resource functionAppNameDiagnosticSettings 'Microsoft.Insights/diagnosticsettings@2017-05-01-preview' = {
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
