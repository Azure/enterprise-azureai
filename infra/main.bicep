targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources (filtered on available regions for Azure Open AI Service).')
@allowed(['westeurope','southcentralus','australiaeast', 'canadaeast', 'eastus', 'eastus2', 'francecentral', 'japaneast', 'northcentralus', 'swedencentral', 'switzerlandnorth', 'uksouth'])
param location string

//Leave blank to use default naming conventions
param resourceGroupName string = ''
param openAiServiceName string = ''
param keyVaultName string = ''
param apimIdentityName string = ''
param funcIdentityName string = ''
param apimServiceName string = ''
param logAnalyticsName string = ''
param applicationInsightsDashboardName string = ''
param applicationInsightsName string = ''
param storageAccountName string = ''
param functionAppName string = ''
param appServicePlanName string = ''
param vnetName string = ''
param apimSubnetName string = ''
param apimNsgName string = ''
param appServiceSubnetName string = ''
param appServiceNsgName string = ''
param privateEndpointSubnetName string = ''
param privateEndpointNsgName string = ''
param redisCacheServiceName string = ''

//Determine the version of the chat model to deploy
param arrayVersion0301Locations array = [
  'westeurope'
  'southcentralus'
]
param chatGptModelVersion string = ((contains(arrayVersion0301Locations, location)) ? '0301' : '0613')

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var openAiSkuName = 'S0'
var chatGptDeploymentName = 'chat'
var chatGptModelName = 'gpt-35-turbo'
var openaiApiKeySecretName = 'openai-apikey'
var functionContentShareName = 'function-content-share'
var tags = { 'azd-env-name': environmentName }

var openAiPrivateDnsZoneName = 'privatelink.openai.azure.com'
var keyVaultPrivateDnsZoneName = 'privatelink.vaultcore.azure.net'
var monitorPrivateDnsZoneName = 'privatelink.monitor.azure.com'
var redisCachePrivateDnsZoneName = 'privatelink.redis.cache.windows.net'
var storageAccountBlobPrivateDnsZoneName = 'privatelink.blob.core.windows.net'
var storageAccountFilePrivateDnsZoneName = 'privatelink.file.core.windows.net'
var appServicePrivateDnsZoneName = 'privatelink.azurewebsites.net'

var privateDnsZoneNames = [
  openAiPrivateDnsZoneName
  keyVaultPrivateDnsZoneName
  monitorPrivateDnsZoneName
  redisCachePrivateDnsZoneName
  storageAccountBlobPrivateDnsZoneName
  storageAccountFilePrivateDnsZoneName
  appServicePrivateDnsZoneName
]

// Organize resources in a resource group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

module dnsDeployment './modules/networking/dns.bicep' = [for privateDnsZoneName in privateDnsZoneNames: {
  name: 'dns-deployment-${privateDnsZoneName}'
  scope: resourceGroup
  params: {
    name: privateDnsZoneName
  }
}]

module managedIdentityApim './modules/security/managed-identity.bicep' = {
  name: 'managed-identity-apim'
  scope: resourceGroup
  params: {
    name: !empty(apimIdentityName) ? apimIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}${resourceToken}-apim'
    location: location
    tags: tags
  }
}

module managedIdentityFunc './modules/security/managed-identity.bicep' = {
  name: 'managed-identity-func'
  scope: resourceGroup
  params: {
    name: !empty(funcIdentityName) ? funcIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}${resourceToken}-func'
    location: location
    tags: tags
  }
}

module keyVault './modules/security/key-vault.bicep' = {
  name: 'key-vault'
  scope: resourceGroup
  params: {
    name: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}${resourceToken}'
    location: location
    tags: tags
    keyVaultPrivateEndpointName: '${abbrs.keyVaultVaults}${abbrs.privateEndpoints}${resourceToken}'
    vNetName: vnet.outputs.vnetName
    privateEndpointSubnetName: vnet.outputs.privateEndpointSubnetName
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
    managedIdentityApimName: managedIdentityApim.outputs.managedIdentityName
    managedIdentityFuncName: managedIdentityFunc.outputs.managedIdentityName
    keyVaultDnsZoneName: keyVaultPrivateDnsZoneName
  }
}

module openaiKeyVaultSecret './modules/security/keyvault-secret.bicep' = {
  name: 'openai-keyvault-secret'
  scope: resourceGroup
  params: {
    keyVaultName: keyVault.outputs.keyVaultName
    secretName: openaiApiKeySecretName
    openAiName: openAi.outputs.openAiName
  }
}

module redisCache './modules/cache/redis.bicep' = {
  name: 'redis-cache'
  scope: resourceGroup
  params: {
    name: !empty(redisCacheServiceName) ? redisCacheServiceName : '${abbrs.cacheRedis}${resourceToken}'
    location: location
    tags: tags
    sku: 'Basic'
    capacity: 1
    redisCachePrivateEndpointName: '${abbrs.cacheRedis}${abbrs.privateEndpoints}${resourceToken}'
    vNetName: vnet.outputs.vnetName
    privateEndpointSubnetName: vnet.outputs.privateEndpointSubnetName
    redisCacheDnsZoneName: redisCachePrivateDnsZoneName
  }
}

module vnet './modules/networking/vnet.bicep' = {
  name: 'vnet'
  scope: resourceGroup
  dependsOn: [
    dnsDeployment
  ]
  params: {
    name: !empty(vnetName) ? vnetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
    apimSubnetName: !empty(apimSubnetName) ? apimSubnetName : '${abbrs.networkVirtualNetworksSubnets}${abbrs.apiManagementService}${resourceToken}'
    apimNsgName: !empty(apimNsgName) ? apimNsgName : '${abbrs.networkNetworkSecurityGroups}${abbrs.apiManagementService}${resourceToken}'
    appServiceSubnetName: !empty(appServiceSubnetName) ? appServiceSubnetName : '${abbrs.networkVirtualNetworksSubnets}${abbrs.webSitesFunctions}${resourceToken}'
    appServiceNsgName: !empty(appServiceNsgName) ? appServiceNsgName : '${abbrs.networkNetworkSecurityGroups}${abbrs.webSitesFunctions}${resourceToken}'
    privateEndpointSubnetName: !empty(privateEndpointSubnetName) ? privateEndpointSubnetName : '${abbrs.networkVirtualNetworksSubnets}${abbrs.privateEndpoints}${resourceToken}'
    privateEndpointNsgName: !empty(privateEndpointNsgName) ? privateEndpointNsgName : '${abbrs.networkNetworkSecurityGroups}${abbrs.privateEndpoints}${resourceToken}'
    location: location
    tags: tags
    privateDnsZoneNames: privateDnsZoneNames
  }
}

module monitoring './modules/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: resourceGroup
  params: {
    location: location
    tags: tags
    logAnalyticsName: !empty(logAnalyticsName) ? logAnalyticsName : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName) ? applicationInsightsName : '${abbrs.insightsComponents}${resourceToken}'
    vNetName: vnet.outputs.vnetName
    privateEndpointSubnetName: vnet.outputs.privateEndpointSubnetName
    applicationInsightsDnsZoneName: monitorPrivateDnsZoneName
    applicationInsightsPrivateEndpointName: '${abbrs.insightsComponents}${abbrs.privateEndpoints}${resourceToken}'
    applicationInsightsDashboardName: !empty(applicationInsightsDashboardName) ? applicationInsightsDashboardName : '${abbrs.portalDashboards}${resourceToken}'
  }
}

module storage './modules/storage/storage-account.bicep' = {
  name: 'storage'
  scope: resourceGroup
  params: {
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
    location: location
    tags: tags
    storageAccountBlobPrivateEndpointName: '${abbrs.storageStorageAccounts}-${abbrs.privateEndpoints}blob-${resourceToken}'
    storageAccountFilePrivateEndpointName: '${abbrs.storageStorageAccounts}-${abbrs.privateEndpoints}file-${resourceToken}'
    vNetName: vnet.outputs.vnetName
    privateEndpointSubnetName: vnet.outputs.privateEndpointSubnetName
    storageAccountBlobDnsZoneName: storageAccountBlobPrivateDnsZoneName
    storageAccountFileDnsZoneName: storageAccountFilePrivateDnsZoneName
    functionContentShareName: functionContentShareName
  }
}

module appServicePlan './modules/host/appserviceplan.bicep' = {
  name: 'appserviceplan'
  scope: resourceGroup
  params: {
    name: !empty(appServicePlanName) ? appServicePlanName : '${abbrs.webServerFarms}${resourceToken}'
    location: location
    tags: tags
    kind: 'Linux'
    sku: {
      name: 'B1'
      tier: 'Basic'
    }
  }
}

module functionApp './modules/host/function.bicep' = {
  name: 'function-app'
  scope: resourceGroup
  params: {
    name: !empty(functionAppName) ? functionAppName : '${abbrs.webSitesFunctions}${resourceToken}'
    location: location
    tags: tags
    appInsightsName: monitoring.outputs.applicationInsightsName
    appServicePlanName: appServicePlan.outputs.appServicePlanName
    storageAccountName: storage.outputs.storageAccountName
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
    managedIdentityName: managedIdentityFunc.outputs.managedIdentityName
    functionAppPrivateEndpointName: '${abbrs.webSitesFunctions}${abbrs.privateEndpoints}${resourceToken}'
    appServicePrivateDnsZoneName: appServicePrivateDnsZoneName
    privateEndpointSubnetName: vnet.outputs.privateEndpointSubnetName
    vNetName: vnet.outputs.vnetName
    appServiceSubnetName: vnet.outputs.appServiceSubnetName
    openAiUri: openAi.outputs.openAiEndpointUri
    keyVaultName: keyVault.outputs.keyVaultName
    openaiApiKeySecretName: openaiKeyVaultSecret.outputs.keyVaultSecretName
    functionContentShareName: functionContentShareName
  }
}

module apim './modules/apim/apim.bicep' = {
  name: 'apim'
  scope: resourceGroup
  params: {
    name: !empty(apimServiceName) ? apimServiceName : '${abbrs.apiManagementService}${resourceToken}'
    location: location
    tags: tags
    sku: 'StandardV2'
    virtualNetworkType: 'External'
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    openaiKeyVaultSecretName: openaiKeyVaultSecret.outputs.keyVaultSecretName
    keyVaultEndpoint: keyVault.outputs.keyVaultEndpoint
    openAiUri: openAi.outputs.openAiEndpointUri
    apimManagedIdentityName: managedIdentityApim.outputs.managedIdentityName
    redisCacheServiceName: redisCache.outputs.cacheName
    apimSubnetId: vnet.outputs.apimSubnetId
    functionAppUri: functionApp.outputs.functionAppUri
  }
}

module openAi 'modules/ai/cognitiveservices.bicep' = {
  name: 'openai'
  scope: resourceGroup
  params: {
    name: !empty(openAiServiceName) ? openAiServiceName : '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    location: location
    tags: tags
    apimManagedIdentityName: managedIdentityApim.outputs.managedIdentityName
    funcManagedIdentityName: managedIdentityFunc.outputs.managedIdentityName
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    sku: {
      name: openAiSkuName
    }
    deployments: [
      {
        name: chatGptDeploymentName
        model: {
          format: 'OpenAI'
          name: chatGptModelName
          version: chatGptModelVersion
        }
        scaleSettings: {
          scaleType: 'Standard'
        }
      }
    ]
    openAiPrivateEndpointName: '${abbrs.cognitiveServicesAccounts}${abbrs.privateEndpoints}${resourceToken}'
    vNetName: vnet.outputs.vnetName
    privateEndpointSubnetName: vnet.outputs.privateEndpointSubnetName
    openAiDnsZoneName: openAiPrivateDnsZoneName
  }
}

output TENTANT_ID string = subscription().tenantId
output AOI_DEPLOYMENTID string = chatGptDeploymentName
output APIM_NAME string = apim.outputs.apimName
output APIM_AOI_PATH string = apim.outputs.apimOpenaiApiPath
