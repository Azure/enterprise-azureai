param location string
param tags object
param chatappIdentityName string
param chatAppName string
param chatServiceName string
param vnetName string
param appServiceSubnetName string
param privateEndpointSubnetName string
param cosmosDbAccountName string
param cosmosPrivateEndpointName string
param cosmosAccountPrivateDnsZoneName string
param appConfigPrivateDnsZoneName string
param keyVaultName string
param keyvaultNamePrivateEndpointName string
param myIpAddress string
param myPrincipalId string
param keyvaultPrivateDnsZoneName string
param OpenAIApiVersion string
param chatappConfigurationName string
param appconfigPrivateEndpointName string
param apimEndpoint string
param apimServiceName string


resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' existing = {
  name: vnetName
}

resource appServiceSubnet 'Microsoft.Network/virtualNetworks/subnets@2024-01-01' existing = {
  parent: vnet
  name: appServiceSubnetName
}


module managedIdentityChatApp './modules/security/managed-identity.bicep' =  {
  name: 'managed-identity-chatapp'
  
  params: {
    name: chatappIdentityName
    location: location
    tags: tags
  }
}

module chatApp 'modules/appservice/azurechat.bicep' = {
  name: 'appservice-app-azurechat'
  
  params: {
    webapp_name: chatAppName
    appservice_name: chatServiceName
    location: location
    tags: tags
    azureChatIdentityName: managedIdentityChatApp.outputs.managedIdentityName
    appConfigEndpoint: appconfigChatApp.outputs.appConfigEndPoint
    subnetId: appServiceSubnet.id
    keyvaultName: keyvault.outputs.keyvaultName
  }
}

module cosmosDb 'modules/cosmosdb/account.bicep' = {
  name: 'cosmosdb'
  
  params: {
    name: cosmosDbAccountName
    location: location
    cosmosAccountPrivateDnsZoneName: cosmosAccountPrivateDnsZoneName
    vNetName: vnetName
    privateEndpointSubnetName: privateEndpointSubnetName
    cosmosPrivateEndpointName: cosmosPrivateEndpointName
    chatAppIdentityName: managedIdentityChatApp.outputs.managedIdentityName
    myIpAddress: myIpAddress
    myPrincipalId: myPrincipalId
    dnsResourceGroupName: resourceGroup().name
    vnetResourceGroupName: resourceGroup().name
  }
}

module appconfigChatApp 'modules/appconfig/configurationStore.bicep' =  {
  name: 'appconfigChatApp-deployment'
  
  params: {
    name: chatappConfigurationName
    location: location
    appconfigPrivateDnsZoneName: appConfigPrivateDnsZoneName
    vnetName: vnetName
    privateEndpointSubnetName: privateEndpointSubnetName
    appconfigPrivateEndpointName: appconfigPrivateEndpointName
    dnsResourceGroupName: resourceGroup().name
    vnetResourceGroupName: resourceGroup().name
  }
}

module appconfigChatAppSettings 'modules/appconfig/appconfig-chatapp.bicep' =  {
  name: 'appconfigChatApp-setting'
  
  params:{
    name: appconfigChatApp.outputs.appConfigName
    apimEndpoint: apimEndpoint
    chatappIdentityName: managedIdentityChatApp.outputs.managedIdentityName
    cosmosDbEndPoint: cosmosDb.outputs.cosmosDbEndPoint
    keyVaultUrl: keyvault.outputs.keyvaultUrl
    openAIApiVersion: OpenAIApiVersion
    myPrincipalId: myPrincipalId
  }
}


module keyvault 'modules/keyvault/keyvault.bicep' =  {
  name: 'keyvault'
  params: {
    name: keyVaultName
    location: location
    chatappIdentityName: managedIdentityChatApp.outputs.managedIdentityName
    vNetName: vnetName
    privateEndpointSubnetName: privateEndpointSubnetName
    keyvaultPrivateEndpointName: keyvaultNamePrivateEndpointName
    keyvaultPrivateDnsZoneName: keyvaultPrivateDnsZoneName
    apimServiceName: apimServiceName
    myIpAddress: myIpAddress
    myPrincipalId: myPrincipalId
    dnsResourceGroupName: resourceGroup().name
    vnetResourceGroupName: resourceGroup().name
    apimResourceGroupName: resourceGroup().name
    
  }
}

output webAppUrl string = chatApp.outputs.webAppUrl
output keyvaultName string = keyvault.outputs.keyvaultName
output managedIdentityClientId string = managedIdentityChatApp.outputs.managedIdentityClientId
