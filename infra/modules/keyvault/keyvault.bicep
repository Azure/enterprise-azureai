param name string
param location string 
param keyvaultPrivateDnsZoneName string
param keyvaultPrivateEndpointName string
param privateEndpointSubnetName string
param vNetName string
param chatappIdentityName string
param apimServiceName string
param myIpAddress string = ''

resource apimService 'Microsoft.ApiManagement/service@2023-03-01-preview' existing = {
  name: apimServiceName
}

resource apimMarketingSubscription 'Microsoft.ApiManagement/service/subscriptions@2021-08-01' existing = {
  name: 'marketing-dept-subscription'
  parent: apimService
}


resource apimFinanceSubscription 'Microsoft.ApiManagement/service/subscriptions@2021-08-01' existing = {
  name: 'finance-dept-subscription'
  parent: apimService
}

resource chatappIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: chatappIdentityName
}



resource keyvault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: name
  location: location
  
  properties: {
    sku: {
      name: 'standard'
      family: 'A'
    }
    enableRbacAuthorization: true
    enableSoftDelete: false
    tenantId: subscription().tenantId
    networkAcls:{
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: [
        {
          value: myIpAddress
        }
      ]
    }
  


  }
}

module chatappRoleAssignment '../roleassignments/roleassignment.bicep' = {
  name: 'kv-chatapp-roleAssignment'
  params: {
    principalId: chatappIdentity.properties.principalId
    roleName: 'Key Vault Secrets User'
    targetResourceId: keyvault.id
    deploymentName: 'chatapp-roleassignment-KeyvaultSecretsUser'
  }
}

resource marketingApiKey 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: 'Marketing'
  parent: keyvault
  properties: {
    attributes: {
      enabled: true
      
    }
    
    value: apimMarketingSubscription.listSecrets(apimMarketingSubscription.apiVersion).primaryKey
  }
}

resource financeApiKey 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  name: 'Finance'
  parent: keyvault
  properties: {
    attributes: {
      enabled: true
      
    }
    value: apimFinanceSubscription.listSecrets(apimFinanceSubscription.apiVersion).primaryKey
  }
}

module privateEndpoint '../networking/private-endpoint.bicep' = {
  name: '${keyvault.name}-privateEndpoint-deployment'
  params: {
    groupIds: [
      'vault'
    ]
    dnsZoneName: keyvaultPrivateDnsZoneName
    name: keyvaultPrivateEndpointName
    subnetName: privateEndpointSubnetName
    privateLinkServiceId: keyvault.id
    vNetName: vNetName
    location: location
  }
}

output keyvaultName string = keyvault.name
output keyvaultUrl string = keyvault.properties.vaultUri
