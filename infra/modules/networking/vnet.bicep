param name string
param location string = resourceGroup().location
param apimSubnetName string
param apimNsgName string
param openaiSubnetName string
param openaiNsgName string
param tags object = {}

resource apimNsg 'Microsoft.Network/networkSecurityGroups@2020-07-01' = {
  name: apimNsgName
  location: location
  tags: union(tags, { 'azd-service-name': apimNsgName })
  properties: {
    securityRules: [
      {
        name: 'AllowAPIMPortal'
        properties: {
            protocol: 'Tcp'
            sourcePortRange: '*'
            destinationPortRange: '3443'
            sourceAddressPrefix: 'ApiManagement'
            destinationAddressPrefix: 'VirtualNetwork'
            access: 'Allow'
            priority: 2721
            direction: 'Inbound'
        }
      }
      {
          name: 'AllowVnetStorage'
          properties: {
              protocol: '*'
              sourcePortRange: '*'
              destinationPortRange: '443'
              sourceAddressPrefix: 'VirtualNetwork'
              destinationAddressPrefix: 'Storage'
              access: 'Allow'
              priority: 2731
              direction: 'Outbound'
          }
      }
      {
          name: 'AllowVnetMonitor'
          properties: {
              protocol: '*'
              sourcePortRange: '*'
              sourceAddressPrefix: 'VirtualNetwork'
              destinationAddressPrefix: 'AzureMonitor'
              access: 'Allow'
              priority: 2741
              direction: 'Outbound'
              destinationPortRanges: [
                  '1886'
                  '443'
              ]
          }
      }
      {
          name: 'AllowAPIMLoadBalancer'
          properties: {
              protocol: '*'
              sourcePortRange: '*'
              destinationPortRange: '6390'
              sourceAddressPrefix: 'AzureLoadBalancer'
              destinationAddressPrefix: 'VirtualNetwork'
              access: 'Allow'
              priority: 2751
              direction: 'Inbound'
          }
      }
      {
          name: 'AllowAPIMFrontdoor'
          properties: {
              protocol: 'Tcp'
              sourcePortRange: '*'
              destinationPortRange: '443'
              sourceAddressPrefix: 'AzureFrontDoor.Backend'
              destinationAddressPrefix: 'VirtualNetwork'
              access: 'Allow'
              priority: 2761
              direction: 'Inbound'
          }
      }
    ]
  }
}

resource openaiNsg 'Microsoft.Network/networkSecurityGroups@2020-07-01' = {
  name: openaiNsgName
  location: location
  tags: union(tags, { 'azd-service-name': openaiNsgName })
  properties: {
    securityRules: [
      {
        name: 'AllowOpenAI'
        properties: {
            protocol: 'Tcp'
            sourcePortRange: '*'
            destinationPortRange: '443'
            sourceAddressPrefix: 'ApiManagement'
            destinationAddressPrefix: 'VirtualNetwork'
            access: 'Allow'
            priority: 2721
            direction: 'Inbound'
        }
      }
    ]
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      {
        name: apimSubnetName
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: apimNsg.id == '' ? null : {
            id: apimNsg.id 
          }
        }
      }
      {
        name: openaiSubnetName
        properties: {
          addressPrefix: '10.0.2.0/24'
          networkSecurityGroup: openaiNsg.id == '' ? null : {
            id: openaiNsg.id
          }
        }
      }
    ]
  }

  resource defaultSubnet 'subnets' existing = {
    name: 'default'
  }

  resource apimSubnet 'subnets' existing = {
    name: apimSubnetName
  }

  resource openaiSubnet 'subnets' existing = {
    name: openaiSubnetName
  }
}

output virtualNetworkId string = virtualNetwork.id
output apimSubnetName string = virtualNetwork::apimSubnet.name
output apimSubnetId string = virtualNetwork::apimSubnet.id
output openaiSubnetName string = virtualNetwork::openaiSubnet.name
output openaiSubnetId string = virtualNetwork::openaiSubnet.id
