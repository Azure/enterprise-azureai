param name string
param location string = resourceGroup().location
param tags object = {}

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
}

output managedIdentityName string = managedIdentity.name
