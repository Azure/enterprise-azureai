param name string = ''
param location string = resourceGroup().location  
param tags object = {}
param identityName string
param imageName string
param containerAppsEnvironmentName string
param containerRegistryName string
param appConfigEndpoint string

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
    azdServiceName: 'azurechat'
    pullFromPrivateRegistry: true
    targetPort: 8080
    external: true
    env: [
      {
        name: 'APPCONFIG_ENDPOINT'
        value: appConfigEndpoint
      }
   
    ]
    
    
  }
}


