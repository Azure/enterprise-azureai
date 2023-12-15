param name string = ''
param location string = resourceGroup().location  
param tags object = {}
param identityName string
param imageName string
param containerAppsEnvironmentName string
param containerRegistryName string
param apimServiceName string
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
    azdServiceName: 'proxy'
    pullFromPrivateRegistry: true
    targetPort: 8080
    apimServiceName: apimServiceName
    env: [
      {
        name: 'APPCONFIGENDPOINT'
        value: appConfigEndpoint
      }
    ]
    
    
  }
}


