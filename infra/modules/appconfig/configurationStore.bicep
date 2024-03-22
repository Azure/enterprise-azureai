param name string
param location string = resourceGroup().location
param appconfigPrivateDnsZoneName string
param appconfigPrivateEndpointName string
param privateEndpointSubnetName string
param vnetName string
param vnetResourceGroupName string = resourceGroup().name
param dnsResourceGroupName string = resourceGroup().name

resource appconfig 'Microsoft.AppConfiguration/configurationStores@2023-03-01' = {
  name: name
  location: location
  sku: {
    name: 'Standard'
  }
  properties:  {
    publicNetworkAccess: 'Enabled'
  }
}


module privateEndpoint '../networking/private-endpoint.bicep' = {
  name: '${appconfig.name}-privateEndpoint-deployment'
  params: {
    groupIds: [
      'configurationStores'
    ]
    dnsZoneName: appconfigPrivateDnsZoneName
    dnsResourceGroupName: dnsResourceGroupName
    name: appconfigPrivateEndpointName
    subnetName: privateEndpointSubnetName
    privateLinkServiceId: appconfig.id
    vNetName: vnetName
    vnetResourceGroupName : vnetResourceGroupName
    location: location
  }
}


output appConfigEndPoint string = appconfig.properties.endpoint
output appConfigName string = appconfig.name
