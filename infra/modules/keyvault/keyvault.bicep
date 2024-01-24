param name string
param location string 
param keyvaultPrivateDnsZoneName string
param keyvaultPrivateEndpointName string
param privateEndpointSubnetName string
param vNetName string
param chatappManagedIndentityName string
param apimServiceName string

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

