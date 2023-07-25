targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

//Leave blank to use default naming conventions
param resourceGroupName string = ''
param openAiServiceName string = ''
param keyVaultName string = ''
param identityName string = ''
param apimServiceName string = ''
param frontDoorName string = ''
param frontDoorWafName string = ''
param logAnalyticsName string = ''
param applicationInsightsDashboardName string = ''
param applicationInsightsName string = ''
param vnetName string = ''
param apimSubnetName string = ''
param apimNsgName string = ''
param openaiSubnetName string = ''
param openaiNsgName string = ''

var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var keyVaultSecretsUserRoleDefinitionId = '4633458b-17de-408a-b874-0445c86b69e6'
var openAiSkuName = 'S0'
var chatGptDeploymentName = 'chat'
var chatGptModelName = 'gpt-35-turbo'
var openaiApiKeySecretName = 'openai-apikey'
var tags = { 'azd-env-name': environmentName }

// Organize resources in a resource group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

module userIdentity './modules/security/managed-identity.bicep' = {
  name: 'userIdentity'
  scope: resourceGroup
  params: {
    name: !empty(identityName) ? identityName : '${abbrs.managedIdentityUserAssignedIdentities}${resourceToken}'
    location: location
    tags: tags
  }
}

module keyVault './modules/security/keyvault.bicep' = {
  name: 'keyvault'
  scope: resourceGroup
  params: {
    name: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}${resourceToken}'
    location: location
    tags: tags
  }
}

module keyVaultRoleAssignment './modules/security/role-assignment.bicep' = {
  name: 'role-assignment'
  scope: resourceGroup
  params: {
    name: guid(keyVaultSecretsUserRoleDefinitionId,userIdentity.outputs.id,keyVault.outputs.id)
    userIdentityPrincipalId: userIdentity.outputs.principalId
    keyVaultSecretsUserRoleDefinitionId: keyVaultSecretsUserRoleDefinitionId
  }
}

module keyVaultAccess './modules/security/keyvault-access.bicep' = {
  name: 'keyvault-access'
  scope: resourceGroup
  params: {
    keyVaultName: keyVault.outputs.name
    apimName: apim.outputs.name
  }
}

module openaiKeyVaultSecret './modules/security/keyvault-secret.bicep' = {
  name: 'openai-keyvault-secret'
  scope: resourceGroup
  params: {
    keyVaultName: keyVault.outputs.name
    secret: openAi.outputs.key
    secretName: openaiApiKeySecretName
  }
}

module vnet './modules/networking/vnet.bicep' = {
  name: 'vnet'
  scope: resourceGroup
  params: {
    name: !empty(vnetName) ? vnetName : '${abbrs.networkVirtualNetworks}${resourceToken}'
    apimSubnetName: !empty(apimSubnetName) ? apimSubnetName : '${abbrs.networkVirtualNetworksSubnets}${resourceToken}-apim'
    apimNsgName: !empty(apimNsgName) ? apimNsgName : '${abbrs.networkNetworkSecurityGroups}${resourceToken}-apim'
    openaiSubnetName: !empty(openaiSubnetName) ? openaiSubnetName : '${abbrs.networkVirtualNetworksSubnets}${resourceToken}-openai'
    openaiNsgName: !empty(openaiNsgName) ? openaiNsgName : '${abbrs.networkNetworkSecurityGroups}${resourceToken}-openai'
    location: location
    tags: tags
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
    applicationInsightsDashboardName: !empty(applicationInsightsDashboardName) ? applicationInsightsDashboardName : '${abbrs.portalDashboards}${resourceToken}'
  }
}

module apim './modules/apim/apim.bicep' = {
  name: 'apim'
  scope: resourceGroup
  params: {
    name: !empty(apimServiceName) ? apimServiceName : '${abbrs.apiManagementService}${resourceToken}'
    location: location
    tags: tags
    applicationInsightsName: monitoring.outputs.applicationInsightsName
    openaiKeyVaultSecretName: openaiKeyVaultSecret.outputs.keyVaultSecretName
    keyVaultName: keyVault.outputs.name
    openaiEndpoint: openAi.outputs.endpoint
    userIdentity: userIdentity.outputs.id
    apimSubnetId: vnet.outputs.apimSubnetId
  }
}

module frontDoor './modules/networking/frontdoor.bicep' = {
  name: 'frontdoor'
  scope: resourceGroup
  params: {
    name: !empty(frontDoorName) ? frontDoorName : '${abbrs.networkFrontDoors}${resourceToken}'
    frontDoorWafName: !empty(frontDoorWafName) ? frontDoorWafName : '${abbrs.networkFirewallPoliciesWebApplication}${resourceToken}'
    apimGwUrl: '${apim.outputs.name}.azure-api.net'
  }
}

//Needed for recursive references
module apimGlobal './modules/apim/apim_global.bicep' = {
  name: 'apim-global'
  scope: resourceGroup
  params: {
    apimName: apim.outputs.name
    frontDoorId: frontDoor.outputs.id
  }
}

module openAi 'modules/ai/cognitiveservices.bicep' = {
  name: 'openai'
  scope: resourceGroup
  params: {
    name: !empty(openAiServiceName) ? openAiServiceName : '${abbrs.cognitiveServicesAccounts}${resourceToken}'
    location: location
    tags: tags
    sku: {
      name: openAiSkuName
    }
    deployments: [
      {
        name: chatGptDeploymentName
        model: {
          format: 'OpenAI'
          name: chatGptModelName
          version: '0301'
        }
        scaleSettings: {
          scaleType: 'Standard'
        }
      }
    ]
  }
}

// App outputs
output TENTANT_ID string = subscription().tenantId
output AOI_NAME string = openAi.outputs.name
output AOI_DEPLOYMENTID string = chatGptDeploymentName
output AOI_APIKEY string = openAi.outputs.key //note: for production use, this should not be exposed
output APIM_NAME string = apim.outputs.name
output APIM_AOI_PATH string = apim.outputs.apimOpenaiApiPath
