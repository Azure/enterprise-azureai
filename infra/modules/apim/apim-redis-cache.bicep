param apimServiceName string
param redisCacheName string

resource apimService 'Microsoft.ApiManagement/service@2023-03-01-preview' existing = {
  name: apimServiceName
}

resource redisCache 'Microsoft.Cache/redis@2022-06-01' existing = {
  name: redisCacheName
}

resource apimCache 'Microsoft.ApiManagement/service/caches@2023-03-01-preview' = {
  name: 'redis-cache'
  parent: apimService
  properties: {
    connectionString: '${redisCache.properties.hostName},password=${redisCache.listKeys().primaryKey},ssl=True,abortConnect=False'
    useFromLocation: 'default'
    description: redisCache.properties.hostName
  }
}
