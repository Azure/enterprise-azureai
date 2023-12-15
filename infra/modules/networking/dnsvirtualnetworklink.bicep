param vnetName string
param dnsZoneName string


resource vnet 'Microsoft.Network/virtualNetworks@2019-11-01' existing = {
  name: vnetName
}

resource dnsVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  name :  '${dnsZoneName}/${vnetName}'
  location: 'global'
  properties: {
    virtualNetwork: {
      id: vnet.id
    }
    registrationEnabled: false
  }
}
