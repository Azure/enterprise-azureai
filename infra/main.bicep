targetScope = 'subscription'

// Main parameters
@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources (filtered on available regions for Azure Open AI Service).')
@allowed(['westeurope','southcentralus','australiaeast', 'canadaeast', 'eastus', 'eastus2', 'francecentral', 'japaneast', 'northcentralus', 'swedencentral', 'switzerlandnorth', 'uksouth'])
param location string

@description('Use Redis Cache for Azure API Management.')
param useRedisCacheForAPIM bool = false

@description('Add Azure Open AI Service to secondary region for load balancing.')
@allowed(['','westeurope','southcentralus','australiaeast', 'canadaeast', 'eastus', 'eastus2', 'francecentral', 'japaneast', 'northcentralus', 'swedencentral', 'switzerlandnorth', 'uksouth'])
param secondaryOpenAILocation string = ''

//Leave blank to use default naming conventions
param resourceGroupName string = ''
param openAiServiceName string = ''
param apimIdentityName string = ''
param chargeBackIdentityName string = ''
param apimServiceName string = ''
param logAnalyticsName string = ''
param dataCollectionEndpointName string = ''
param dataCollectionRuleName string = ''
param applicationInsightsDashboardName string = ''
param applicationInsightsName string = ''
param chargeBackAppName string = ''
param vnetName string = ''
param apimSubnetName string = ''
param apimNsgName string = ''
param acaSubnetName string = ''
param acaNsgName string = ''
param privateEndpointSubnetName string = ''
param privateEndpointNsgName string = ''
param redisCacheServiceName string = ''
param containerRegistryName string = ''
param containerAppsEnvironmentName string = ''
param appConfigurationName string = ''
param myIpAddress string = ''

param apimSku string = 'Developer' //StandardV2, error on creating: service is not active.


//Determine the version of the chat model to deploy
param arrayVersion0301Locations array = [
  'westeurope'
  'southcentralus'
]
param gptModelVersion string = ((contains(arrayVersion0301Locations, location)) ? '0301' : '0613')
param gptModelVersionSecondary string = ((contains(arrayVersion0301Locations, secondaryOpenAILocation)) ? '0301' : '0613')

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var openAiSkuName = 'S0'
var gptDeploymentName = 'gpt-35-turbo'
var gptModelName = 'gpt-35-turbo'
var embeddingDeploymentName = 'text-embedding-ada-002'
var embeddingModelName = 'text-embedding-ada-002'
var embeddingModelVersion = '2'
var embeddingModelVersionSecondary = '2'
var tags = { 'azd-env-name': environmentName }

var openAiPrivateDnsZoneName = 'privatelink.openai.azure.com'
var monitorPrivateDnsZoneName = 'privatelink.monitor.azure.com'
var redisCachePrivateDnsZoneName = 'privatelink.redis.cache.windows.net'
var appConfigPrivateDnsZoneName = 'privatelink.azconfig.io'
var containerRegistryPrivateDnsZoneName = 'privatelink.azurecr.io'

var privateDnsZoneNames = [
  openAiPrivateDnsZoneName
  monitorPrivateDnsZoneName
  redisCachePrivateDnsZoneName
  containerRegistryPrivateDnsZoneName
  appConfigPrivateDnsZoneName
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

module managedIdentityChargeBack './modules/security/managed-identity.bicep' = {
  name: 'managed-identity-chargeback'
  scope: resourceGroup
  params: {
    name: !empty(chargeBackIdentityName) ? chargeBackIdentityName : '${abbrs.managedIdentityUserAssignedIdentities}${resourceToken}-cb'
    location: location
    tags: tags
  }
}

module redisCache './modules/cache/redis.bicep' = if(useRedisCacheForAPIM){
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
    acaSubnetName: !empty(acaSubnetName) ? acaSubnetName : '${abbrs.networkVirtualNetworksSubnets}${abbrs.appContainerApps}${resourceToken}'
    acaNsgName: !empty(acaNsgName) ? acaNsgName : '${abbrs.networkNetworkSecurityGroups}${abbrs.appContainerApps}${resourceToken}'
    privateEndpointSubnetName: !empty(privateEndpointSubnetName) ? privateEndpointSubnetName : '${abbrs.networkVirtualNetworksSubnets}${abbrs.privateEndpoints}${resourceToken}'
    privateEndpointNsgName: !empty(privateEndpointNsgName) ? privateEndpointNsgName : '${abbrs.networkNetworkSecurityGroups}${abbrs.privateEndpoints}${resourceToken}'
    location: location
    tags: tags
    privateDnsZoneNames: privateDnsZoneNames
    apimSku: apimSku
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
    dataCollectionEndpointName: !empty(dataCollectionEndpointName) ? dataCollectionEndpointName : '${abbrs.dataCollectionEndpoints}${resourceToken}'
    dataCollectionRuleName: !empty(dataCollectionRuleName) ? dataCollectionRuleName : '${abbrs.dataCollectionRules}${resourceToken}'
    vNetName: vnet.outputs.vnetName
    privateEndpointSubnetName: vnet.outputs.privateEndpointSubnetName
    applicationInsightsDnsZoneName: monitorPrivateDnsZoneName
    applicationInsightsPrivateEndpointName: '${abbrs.insightsComponents}${abbrs.privateEndpoints}${resourceToken}'
    applicationInsightsDashboardName: !empty(applicationInsightsDashboardName) ? applicationInsightsDashboardName : '${abbrs.portalDashboards}${resourceToken}'
    chargeBackManagedIdentityName: managedIdentityChargeBack.outputs.managedIdentityName
    
  }
}


module apim './modules/apim/apim.bicep' = {
  name: 'apim'
  scope: resourceGroup
  params: {
    name: !empty(apimServiceName) ? apimServiceName : '${abbrs.apiManagementService}${resourceToken}'
    location: location
    tags: tags
    sku: apimSku
    virtualNetworkType: 'External'
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    apimManagedIdentityName: managedIdentityApim.outputs.managedIdentityName
    redisCacheServiceName: useRedisCacheForAPIM ? redisCache.outputs.cacheName : ''
    apimSubnetId: vnet.outputs.apimSubnetId
  }
}

module openAi './modules/ai/cognitiveservices.bicep' = {
  name: 'openai'
  scope: resourceGroup
  params: {
    name: !empty(openAiServiceName) ? openAiServiceName : '${abbrs.cognitiveServicesAccounts}${resourceToken}-${location}'
    location: location
    tags: tags
    chargeBackManagedIdentityName: managedIdentityChargeBack.outputs.managedIdentityName
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    sku: {
      name: openAiSkuName
    }
    deployments: [
      {
        name: gptDeploymentName
        model: {
          format: 'OpenAI'
          name: gptModelName
          version: gptModelVersion
        }
        scaleSettings: {
          scaleType: 'Standard'
        }
      }
      {
        name: embeddingDeploymentName
        model: {
          format: 'OpenAI'
          name: embeddingModelName
          version: embeddingModelVersion
        }
      }
    ]
    openAiPrivateEndpointName: '${abbrs.cognitiveServicesAccounts}${abbrs.privateEndpoints}${resourceToken}-${location}'
    vNetName: vnet.outputs.vnetName
    privateEndpointSubnetName: vnet.outputs.privateEndpointSubnetName
    openAiDnsZoneName: openAiPrivateDnsZoneName
  }
}

module openAiSecondary './modules/ai/cognitiveservices.bicep' = if (secondaryOpenAILocation != '') {
  name: 'openai-secondary'
  scope: resourceGroup
  params: {
    name: !empty(openAiServiceName) ? openAiServiceName : '${abbrs.cognitiveServicesAccounts}${resourceToken}-${secondaryOpenAILocation}'
    location: secondaryOpenAILocation
    tags: tags
    chargeBackManagedIdentityName: managedIdentityChargeBack.outputs.managedIdentityName
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
    sku: {
      name: openAiSkuName
    }
    deployments: [
      {
        name: gptDeploymentName
        model: {
          format: 'OpenAI'
          name: gptModelName
          version: gptModelVersionSecondary
        }
        scaleSettings: {
          scaleType: 'Standard'
        }
      }
      {
        name: embeddingDeploymentName
        model: {
          format: 'OpenAI'
          name: embeddingModelName
          version: embeddingModelVersionSecondary
        }
      }

    ]
    openAiPrivateEndpointName: '${abbrs.cognitiveServicesAccounts}${abbrs.privateEndpoints}${resourceToken}-${secondaryOpenAILocation}'
    vNetName: vnet.outputs.vnetName
    privateEndpointSubnetName: vnet.outputs.privateEndpointSubnetName
    openAiDnsZoneName: openAiPrivateDnsZoneName
  }
}

module containerRegistry './modules/host/container-registry.bicep' = {
  name: 'container-registry'
  scope: resourceGroup
  params: {
    name: !empty(containerRegistryName) ? containerRegistryName : '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    tags: tags
    chargeBackManagedIdentityName: managedIdentityChargeBack.outputs.managedIdentityName
    myIpAddress: myIpAddress
    //needed for container app deployment
    adminUserEnabled: true
    publicNetworkAccess: myIpAddress == '' ? 'Disabled': 'Enabled'
    containerRegistryDnsZoneName: containerRegistryPrivateDnsZoneName
    containerRegistryPrivateEndpointName: '${abbrs.containerRegistryRegistries}-${abbrs.privateEndpoints}${resourceToken}'
    vNetName: vnet.outputs.vnetName
    privateEndpointSubnetName: vnet.outputs.privateEndpointSubnetName
    
  }
}

module containerAppsEnvironment './modules/host/container-app-environment.bicep' = {
  name: 'container-apps-environment'
  scope: resourceGroup
  params: {
    name: !empty(containerAppsEnvironmentName) ? containerAppsEnvironmentName : '${abbrs.appManagedEnvironments}${resourceToken}' 
    location: location
    tags: tags
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    vnetName: vnet.outputs.vnetName
    subnetName: vnet.outputs.acaSubnetName
  }
}

module app './modules/host/container-app.bicep' = {
  name: 'container-app'
  scope: resourceGroup
  params: {
    name: !empty(chargeBackAppName) ? chargeBackAppName : '${abbrs.appContainerApps}${resourceToken}-cb'
    location: location
    tags: tags
    identityName: managedIdentityChargeBack.outputs.managedIdentityName
    //deploy sample image first - we need the endpoint already for APIM
    //real image will be deployed later
    imageName: ''
    apimServiceName: apim.outputs.apimName
    external: true
    env: [
      {
        name: 'APPCONFIG_ENDPOINT'
        value: appconfig.outputs.appConfigEndPoint
      }
      {
        name: 'CLIENT_ID'
        value: managedIdentityChargeBack.outputs.managedIdentityClientId
      }
    ]
    pullFromPrivateRegistry: true
    azdServiceName: 'proxy'
    containerAppsEnvironmentName: containerAppsEnvironment.outputs.name
    containerRegistryName: containerRegistry.outputs.name
    targetPort: 8080
  }
  dependsOn: [
    containerRegistry
    containerAppsEnvironment
  ]
}

module appconfig 'modules/appconfig/appconfiguration.bicep' = {
  name: 'appconfig'
  scope: resourceGroup
  params: {
    name: !empty(appConfigurationName) ? appConfigurationName : '${abbrs.appConfigurationConfigurationStores}${resourceToken}'
    AzureMonitorDataCollectionEndPointUrl: monitoring.outputs.dataCollectionEndpointUrl
    AzureMonitorDataCollectionRuleStream: monitoring.outputs.dataCollectionRuleStreamName
    AzureMonitorDataCollectionRuleImmutableId: monitoring.outputs.dataCollectionRuleImmutableId
    location: location
    AzureOpenAIEndpoints: array(openAi.outputs.openAIEndpointUriRaw)
    proxyManagedIdentityName: managedIdentityChargeBack.outputs.managedIdentityName
    
  }
}

output TENTANT_ID string = subscription().tenantId
output DEPLOYMENT_LOCATION string = location
output APIM_NAME string = apim.outputs.apimName
output RESOURCE_TOKEN string = resourceToken
output AZURE_CONTAINER_ENVIRONMENT_NAME string = containerAppsEnvironment.outputs.name
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.outputs.name
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer
output AZURE_PROXY_MANAGED_IDENTITY_NAME string = managedIdentityChargeBack.outputs.managedIdentityName
output AZURE_APPCONFIG_ENDPOINT string = appconfig.outputs.appConfigEndPoint
output AZURE_RESOURCE_GROUP string = resourceGroup.name
