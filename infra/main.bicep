targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources (filtered on available regions for Azure Open AI Service).')
@allowed(['westeurope','southcentralus','australiaeast', 'canadaeast', 'eastus', 'eastus2', 'francecentral', 'japaneast', 'northcentralus', 'swedencentral', 'switzerlandnorth', 'uksouth'])
param location string

// Needed for isolated deployment, check if this can be removed
//@description('IP address of the machine running the deployment.')
//param myIpAddress string

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
param appServiceSubnetName string = ''
param appServiceNsgName string = ''
param privateEndpointSubnetName string = ''
param privateEndpointNsgName string = ''
param redisCacheServiceName string = ''
param eventHubNamespaceName string = ''
param containerRegistryName string = ''
param containerAppsEnvironmentName string = ''
param appConfigurationName string = ''


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
var eventHubListenPolicyName = 'listen'
var eventHubSendPolicyName = 'send'
var eventHubName = 'openai-logging'
var tags = { 'azd-env-name': environmentName }

var openAiPrivateDnsZoneName = 'privatelink.openai.azure.com'
var monitorPrivateDnsZoneName = 'privatelink.monitor.azure.com'
var redisCachePrivateDnsZoneName = 'privatelink.redis.cache.windows.net'
var eventHubPrivateDnsZoneName = 'privatelink.servicebus.windows.net'

var privateDnsZoneNames = [
  openAiPrivateDnsZoneName
  monitorPrivateDnsZoneName
  redisCachePrivateDnsZoneName
  eventHubPrivateDnsZoneName
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

module eventHub './modules/monitor/eventhub.bicep' = {
  name: 'event-hub'
  scope: resourceGroup
  params: {
    name: !empty(eventHubNamespaceName) ? eventHubNamespaceName : '${abbrs.eventHubNamespaces}${resourceToken}'
    location: location
    tags: tags
    eventHubListenPolicyName: eventHubListenPolicyName
    eventHubSendPolicyName: eventHubSendPolicyName
    apimManagedIdentityName: managedIdentityApim.outputs.managedIdentityName
    chargeBackManagedIdentityName: managedIdentityChargeBack.outputs.managedIdentityName
    eventHubName: !empty(eventHubName) ? eventHubName : '${abbrs.eventHubNamespacesEventHubs}${resourceToken}'
    eventHubPrivateEndpointName: '${abbrs.eventHubNamespaces}${abbrs.privateEndpoints}${resourceToken}'
    vNetName: vnet.outputs.vnetName
    privateEndpointSubnetName: vnet.outputs.privateEndpointSubnetName
    eventHubDnsZoneName: eventHubPrivateDnsZoneName
  }
}

module apim './modules/apim/apim.bicep' = {
  name: 'apim'
  scope: resourceGroup
  params: {
    name: !empty(apimServiceName) ? apimServiceName : '${abbrs.apiManagementService}${resourceToken}'
    location: location
    tags: tags
    sku: 'StandardV2' //StandardV2
    virtualNetworkType: 'External'
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    apimManagedIdentityName: managedIdentityApim.outputs.managedIdentityName
    redisCacheServiceName: redisCache.outputs.cacheName
    apimSubnetId: vnet.outputs.apimSubnetId
    eventHubName: eventHub.outputs.eventHubName
    eventHubNamespaceName: eventHub.outputs.eventHubNamespaceName
  }
}

module openAi './modules/ai/cognitiveservices.bicep' = {
  name: 'openai'
  scope: resourceGroup
  params: {
    name: !empty(openAiServiceName) ? openAiServiceName : '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    location: location
    tags: tags
    apimManagedIdentityName: managedIdentityApim.outputs.managedIdentityName
    chargeBackManagedIdentityName: managedIdentityChargeBack.outputs.managedIdentityName
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

module containerRegistry './modules/host/container-registry.bicep' = {
  name: 'container-registry'
  scope: resourceGroup
  params: {
    name: !empty(containerRegistryName) ? containerRegistryName : '${abbrs.containerRegistryRegistries}${resourceToken}'
    location: location
    tags: tags
    chargeBackManagedIdentityName: managedIdentityChargeBack.outputs.managedIdentityName
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
    pullFromPrivateRegistry: false
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
  }
}

output TENTANT_ID string = subscription().tenantId
output AOI_DEPLOYMENTID string = chatGptDeploymentName
output DEPLOYMENT_LOCATION string = location
output APIM_NAME string = apim.outputs.apimName
output RESOURCE_TOKEN string = resourceToken
output AZURE_CONTAINER_ENVIRONMENT_NAME string = containerAppsEnvironment.outputs.name
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.outputs.name
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer
output AZURE_PROXY_MANAGED_IDENTITY_NAME string = managedIdentityChargeBack.outputs.managedIdentityName
