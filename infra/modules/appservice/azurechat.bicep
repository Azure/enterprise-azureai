param appservice_name string
param location string
param tags object
param webapp_name string
param appConfigEndpoint string
param azureChatIdentityName string
param subnetId string
param keyvaultName string


var nextAuthHash = uniqueString(azureChatIdentityName)


resource userIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing =  {
  name: azureChatIdentityName
}



resource appServicePlan 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: appservice_name
  location: location
  tags: tags
  properties: {
    reserved: true
  }
  sku: {
    name: 'P0v3'
    tier: 'Premium0V3'
    size: 'P0v3'
    family: 'Pv3'
    capacity: 1
  }
  kind: 'linux'
  
}

resource webApp 'Microsoft.Web/sites@2023-01-01' = {
  name: webapp_name
  location: location
  tags: union(tags, { 'azd-service-name': 'azurechat' })
  properties: {
    serverFarmId: appServicePlan.id
    virtualNetworkSubnetId: subnetId
    httpsOnly: true
    keyVaultReferenceIdentity: userIdentity.id
    siteConfig: {
      linuxFxVersion: 'node|18-lts'
      alwaysOn: true
      appCommandLine: 'next start'
      ftpsState: 'Disabled'
      minTlsVersion: '1.2'
      appSettings: [ 
        {
          name: 'APPCONFIG_ENDPOINT'
          value: appConfigEndpoint
        }
        {
          name: 'NEXTAUTH_SECRET'
          value: nextAuthHash
        }
        {
          name: 'NEXTAUTH_URL'
          value: 'https://${webapp_name}.azurewebsites.net'
        }
        { 
          name: 'SCM_DO_BUILD_DURING_DEPLOYMENT'
          value: 'true'
        }
        {
          name: 'AZURE_CLIENT_ID'
          value: userIdentity.properties.clientId
        }
        {
          name: 'AZURE_TENANT_ID'
          value: userIdentity.properties.tenantId
        }
        {
          name: 'AUTH_ENTRA_CLIENT_ID'
          value: '@Microsoft.KeyVault(VaultName=${keyvaultName};SecretName=AzureChatClientId)'
        }
        {
          name: 'AUTH_ENTRA_CLIENT_SECRET'
          value: '@Microsoft.KeyVault(VaultName=${keyvaultName};SecretName=AzureChatClientSecret)'
        }

        
      ]
    }
    
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userIdentity.id}': {}
    }
  }
}

output webAppUrl string = 'https://${webApp.properties.defaultHostName}'
output name string = webApp.name
