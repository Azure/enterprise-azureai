param name string 
param chatappIdentityName string
param cosmosDbEndPoint string
param apimEndpoint string
param keyVaultUrl string
param openAIApiVersion string
param myPrincipalId string


resource chatappIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: chatappIdentityName
}

resource appconfig 'Microsoft.AppConfiguration/configurationStores@2023-03-01' existing = {
  name: name

}

module currentUserRoleAssignment '../roleassignments/roleassignment.bicep' = {
  name: 'currentuser-roleAssignment'
  params: {
    principalId: myPrincipalId
    roleName: 'App Configuration Data Reader'
    targetResourceId: appconfig.id
    deploymentName: 'currentuser-roleassignment-AppConfigurationDataReader'
    principalType: 'User'
  }
}

module chatappRoleAssignment '../roleassignments/roleassignment.bicep' = {
  name: 'chatapp-roleAssignment'
  params: {
    principalId: chatappIdentity.properties.principalId
    roleName: 'App Configuration Data Reader'
    targetResourceId: appconfig.id
    deploymentName: 'chatapp-roleassignment-AppConfigurationDataReader'
  }
}


module EntraIdTenantId 'configurationStoreKeyValues.bicep' = {
  name: 'EntraId-TenantId'
  params: {
    appconfigName : appconfig.name
    key : 'EntraId:TenantId'
    value: subscription().tenantId
  }
}


module cosmosDb 'configurationStoreKeyValues.bicep' = {
  name: 'AzureChat-CosmosDbEndPoint'
  params: {
    appconfigName : appconfig.name
    key :  'AzureChat:CosmosDbEndPoint'
    value: cosmosDbEndPoint
  }
}

//this will be used to create the departments in the app config store for the chat app
var departmentsConfig = [
  {
    name: 'Finance'
  }
  {
    name: 'Marketing'
  }
]

module departments 'configurationStoreKeyValues.bicep' = {
  name: 'AzureChat-Departments'
  params: {
    appconfigName : appconfig.name
    key :  'AzureChat:Departments'
    value: string(departmentsConfig)
  }
}

//this will be used to create the deployments in the app config store for the chat app
var deploymentsConfig = [
  {
    type: 'chat'
    deployment: 'gpt-35-turbo'
  }
  {
    type: 'embeddings'
    deployment: 'text-embeddings-ada-002'
  }
]

module deployments 'configurationStoreKeyValues.bicep' = {
  name: 'AzureChat-Deployments'
  params: {
    appconfigName : appconfig.name
    key :  'AzureChat:Deployments'
    value: string(deploymentsConfig)
  }
}

module OpenAIEndpoint  'configurationStoreKeyValues.bicep' = {
  name: 'AzureChat-ApimEndpoint'
  params: {
    appconfigName : appconfig.name
    key :  'AzureChat:ApimEndpoint'
    value: apimEndpoint
  }
}

module KeyVaultEndpoint  'configurationStoreKeyValues.bicep' = {
  name: 'AzureChat-Keyvault'
  params: {
    appconfigName : appconfig.name
    key :  'AzureChat:Keyvault'
    value: keyVaultUrl
  }
}

module OpenAIAPIVersion 'configurationStoreKeyValues.bicep' = {
  name: 'AzureChat-OpenAIApiVersion'
  params: {
    appconfigName : appconfig.name
    key :  'AzureChat:OpenAIApiVersion'
    value: openAIApiVersion
  }
}

