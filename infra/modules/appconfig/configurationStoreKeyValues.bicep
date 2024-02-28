param appconfigName string
param key string
param value string

resource appconfig 'Microsoft.AppConfiguration/configurationStores@2023-03-01' existing = {
  name: appconfigName
}

resource keyvalue 'Microsoft.AppConfiguration/configurationStores/keyValues@2023-03-01' = {
  name: key
  parent: appconfig
  properties:{
    value: value
  }
}
