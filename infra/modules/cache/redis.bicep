param name string
param location string = resourceGroup().location
param apimServiceName string
param tags object = {}

@description('The pricing tier of the new Azure Cache for Redis instance')
@allowed([ 'Basic', 'Standard', 'Premium' ])
param sku string = 'Basic'

@description('Specify the size of the new Azure Redis Cache instance. Valid values: for C (Basic/Standard) family (0, 1, 2, 3, 4, 5, 6), for P (Premium) family (1, 2, 3, 4)')
@minValue(0)
@maxValue(6)
param capacity int = 1
param publicNetworkAccess string = 'Disabled'

//Private Endpoint settings
param redisCachePrivateEndpointName string
param vNetName string
param privateEndpointSubnetName string
param redisCacheDnsZoneName string

var skuFamily = (sku == 'Premium') ? 'P' : 'C'

resource redisCache 'Microsoft.Cache/redis@2022-06-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  properties: {
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    publicNetworkAccess: publicNetworkAccess
    sku: {
      capacity: capacity
      family: skuFamily
      name: sku
    }
  }
}

module privateEndpoint '../networking/private-endpoint.bicep' = {
  name: '${redisCache.name}-privateEndpoint-deployment'
  params: {
    groupIds: [
      'redisCache'
    ]
    dnsZoneName: redisCacheDnsZoneName
    name: redisCachePrivateEndpointName
    subnetName: privateEndpointSubnetName
    privateLinkServiceId: redisCache.id
    vNetName: vNetName
    location: location
  }
}

module apimRedisCache '../apim/apim-redis-cache.bicep' = {
  name: 'apim-redis-cache-deployment'
  params: {
    apimServiceName: apimServiceName
    redisCacheName: redisCache.name
  }
}

output cacheName string = redisCache.name
output hostName string = redisCache.properties.hostName
