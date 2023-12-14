param name string = ''
param location string = resourceGroup().location  
param tags object = {}
param identityName string
param imageName string
param containerAppsEnvironmentName string
param containerRegistryName string
param apimServiceName string


module app '../modules/host/container-app.bicep' = {
  name: 'container-app'
  params: {
    name: name
    location: location
    tags: tags
    identityName: identityName
    imageName: imageName
    containerAppsEnvironmentName: containerAppsEnvironmentName
    containerRegistryName: containerRegistryName
    azdServiceName: 'proxy'
    pullFromPrivateRegistry: false
    targetPort: 8080
  }
}

module apim '../modules/apim/apim-backend.bicep' = {
  name: 'apim-backend'
  params: {
    apimServiceName: apimServiceName
    chargeBackApiBackendId: 'chargeback-backend'
    chargeBackAppUri: app.outputs.uri
  }
}
