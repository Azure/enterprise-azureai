param name string
param location string = resourceGroup().location
param tags object = {}

resource userIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
}

output id string = userIdentity.id
output principalId string = userIdentity.properties.principalId
