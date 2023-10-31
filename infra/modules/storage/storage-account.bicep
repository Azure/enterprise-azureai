param name string
param location string = resourceGroup().location
param tags object = {}

param containers array = []
param kind string = 'StorageV2'
param minimumTlsVersion string = 'TLS1_2'
param sku object = { name: 'Standard_LRS' }
param functionContentShareName string
//Private Endpoint settings
param storageAccountBlobPrivateEndpointName string
param storageAccountFilePrivateEndpointName string
param vNetName string
param privateEndpointSubnetName string
param storageAccountBlobDnsZoneName string
param storageAccountFileDnsZoneName string

param allowBlobPublicAccess bool = false
param publicNetworkAccess string = 'Disabled'

resource storage 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  kind: kind
  sku: sku
  properties: {
    minimumTlsVersion: minimumTlsVersion
    publicNetworkAccess: publicNetworkAccess
    allowBlobPublicAccess: allowBlobPublicAccess
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Deny'
    }
  }

  resource blobServices 'blobServices' = if (!empty(containers)) {
    name: 'default'
    resource container 'containers' = [for container in containers: {
      name: container.name
      properties: {
        publicAccess: contains(container, 'publicAccess') ? container.publicAccess : 'None'
      }
    }]
  }
}

resource share 'Microsoft.Storage/storageAccounts/fileServices/shares@2022-05-01' = {
  name: '${storage.name}/default/${functionContentShareName}'
  dependsOn: [
    storage
  ]
}

//Private Endpoints
module privateEndpointBlob '../networking/private-endpoint.bicep' = {
  name: '${storage.name}-privateEndpoint-deployment-blob'
  params: {
    groupIds: [
      'blob'
    ]
    dnsZoneName: storageAccountBlobDnsZoneName
    name: storageAccountBlobPrivateEndpointName
    subnetName: privateEndpointSubnetName
    privateLinkServiceId: storage.id
    vNetName: vNetName
    location: location
  }
}

module privateEndpointFile '../networking/private-endpoint.bicep' = {
  name: '${storage.name}-privateEndpoint-deployment-file'
  params: {
    groupIds: [
      'file'
    ]
    dnsZoneName: storageAccountFileDnsZoneName
    name: storageAccountFilePrivateEndpointName
    subnetName: privateEndpointSubnetName
    privateLinkServiceId: storage.id
    vNetName: vNetName
    location: location
  }
}

output storageAccountName string = storage.name
output storagePrimaryEndpoints object = storage.properties.primaryEndpoints
