targetScope = 'subscription'

@minLength(1)
@maxLength(64)
@description('Name of the the environment which is used to generate a short unique hash used in all resources.')
param environmentName string

@minLength(1)
@description('Primary location for all resources')
param location string

@description('Id of the user or app to assign application roles')
param principalId string = ''

@description('Leave blank to use default naming convention')
param aadClientApplicationName string = ''
param resourceGroupName string = ''
param openAiServiceName string = ''
param keyVaultName string = ''
param apimServiceName string = ''
param logAnalyticsName string = ''
param applicationInsightsDashboardName string = ''
param applicationInsightsName string = ''

param openAiSkuName string = 'S0'
param chatGptDeploymentName string = 'chat'
param chatGptModelName string = 'gpt-35-turbo'

var subscriptionId = subscription().id
var abbrs = loadJsonContent('./abbreviations.json')
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))
var tags = { 'azd-env-name': environmentName }

// Organize resources in a resource group
resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

module appreg './modules/azuread/appregistration.bicep' = {
  name: 'appreg'
  scope: resourceGroup
  params: {
    name: !empty(aadClientApplicationName) ? aadClientApplicationName : 'appreg-${environmentName}'
    location: location
  }
}

module keyVault './modules/security/keyvault.bicep' = {
  name: 'keyvault'
  scope: resourceGroup
  params: {
    name: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}${resourceToken}'
    location: location
    tags: tags
    principalId: principalId
  }
}

module keyVaultAccess './modules/security/keyvault-access.bicep' = {
  name: 'keyvault-access'
  scope: resourceGroup
  params: {
    keyVaultName: keyVault.outputs.name
  }
}

module keyVaultSecret './modules/security/keyvault-secret.bicep' = {
  name: 'keyvault-secret'
  scope: resourceGroup
  params: {
    keyVaultName: keyVault.outputs.name
    openaiApiKey: openAi.outputs.key
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
    keyVaultSecretName: keyVaultSecret.outputs.keyVaultSecretName
    keyVaultName: keyVault.outputs.name
    openaiEndpoint: openAi.outputs.endpoint
    aadClientApplicationId: appreg.outputs.clientId
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
output AOI_NAME string = openAi.outputs.name
output AOI_DEPLOYMENTID string = chatGptDeploymentName
output AOI_APIKEY string = openAi.outputs.key //note: for production use, this should not be exposed
output CLIENT_ID string = appreg.outputs.clientId
output CLIENT_SECRET string = appreg.outputs.clientSecret
output TENANT_ID string = tenant().tenantId
output APIM_NAME string = apim.outputs.apimServiceName
output APIM_AOI_PATH string = apim.outputs.apimOpenaiApiPath
output AZURE_PORTAL_APIM string = 'https://portal.azure.com/resource/subscriptions/${subscriptionId}/resourceGroups/${resourceGroup.name}/providers/Microsoft.ApiManagement/service/${apim.outputs.apimServiceName}/apim-apis'
