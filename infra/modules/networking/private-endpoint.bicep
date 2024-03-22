param name string
param subnetName string
param vNetName string
param privateLinkServiceId string
param groupIds array
param dnsZoneName string
param location string
param vnetResourceGroupName string = resourceGroup().name
param dnsResourceGroupName string = resourceGroup().name

resource rgNetwork 'Microsoft.Resources/resourceGroups@2023-07-01' existing = {
  name: vnetResourceGroupName
  scope: subscription()
}

resource rgDns 'Microsoft.Resources/resourceGroups@2023-07-01' existing = {
  name: dnsResourceGroupName
  scope: subscription()
}

resource privateEndpointSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-09-01' existing = {
  name: '${vNetName}/${subnetName}'
  scope: rgNetwork
}

resource privateEndpointDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' existing = {
  name: dnsZoneName
  scope: rgDns
}

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-09-01' = {
  name: name
  location: location
  properties: {
    subnet: {
      id: privateEndpointSubnet.id
    }
    privateLinkServiceConnections: [
      {
        name: name
        properties: {
          privateLinkServiceId: privateLinkServiceId
          groupIds: groupIds
        }
      }
    ]
  }
}

resource privateEndpointDnsGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-09-01' = {
  parent: privateEndpoint
  name: 'privateDnsZoneGroup'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'default'
        properties: {
          privateDnsZoneId: privateEndpointDnsZone.id
        }
      }
    ]
  }
}

output privateEndpointName string = privateEndpoint.name
