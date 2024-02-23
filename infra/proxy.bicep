param name string = ''
param location string = resourceGroup().location  
param tags object = {}
param identityName string
param imageName string
param containerAppsEnvironmentName string
param containerRegistryName string
param appConfigEndpoint string
param appInsightsConnectionString string
param managedIdentityName string

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' existing = {
  name: managedIdentityName
}

module app 'modules/host/container-app.bicep' = {
  name: 'container-app'
  params: {
    name: name
    location: location
    tags: tags
    identityName: identityName
    imageName: imageName
    containerAppsEnvironmentName: containerAppsEnvironmentName
    containerRegistryName: containerRegistryName
    containerName: imageName
    azdServiceName: 'proxy'
    pullFromPrivateRegistry: true
    targetPort: 8080
    external: true
    env: [
      {
        name: 'APPCONFIG_ENDPOINT'
        value: appConfigEndpoint
      }
      {
        name: 'CLIENT_ID'
        value: managedIdentity.properties.clientId
      }
      {
        name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
        value: appInsightsConnectionString
      }
    ]
    
  }
}

