param name string
param location string = resourceGroup().location
param tags object = {}

@description('Allowed origins')
param allowedOrigins array = []

@description('Name of the environment for container apps')
param containerAppsEnvironmentName string

@description('CPU cores allocated to a single container instance, e.g., 0.5')
param containerCpuCoreCount string = '0.5'

@description('The maximum number of replicas to run. Must be at least 1.')
@minValue(1)
param containerMaxReplicas int = 10

@description('Memory allocated to a single container instance, e.g., 1Gi')
param containerMemory string = '1.0Gi'

@description('The minimum number of replicas to run. Must be at least 1.')
param containerMinReplicas int = 1

@description('The name of the container')
param containerName string = 'main'

@description('The name of the container registry')
param containerRegistryName string = ''

@description('The environment variables for the container')
param env array = []


@description('The name of the user-assigned identity')
param identityName string

@description('The name of the container image')
param imageName string = ''

@description('Specifies if Ingress is enabled for the container app')
param ingressEnabled bool = true

param revisionMode string = 'Single'

@description('The target port for the container')
param targetPort int

param pullFromPrivateRegistry bool = true

param azdServiceName string 

param apimServiceName string

resource userIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = if (!empty(identityName)) {
  name: identityName
}

resource app 'Microsoft.App/containerApps@2023-04-01-preview' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': azdServiceName })
  // It is critical that the identity is granted ACR pull access before the app is created
  // otherwise the container app will throw a provision error
  // This also forces us to use an user assigned managed identity since there would no way to 
  // provide the system assigned identity with the ACR pull access before the app is created
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      activeRevisionsMode: revisionMode
      ingress: ingressEnabled ? {
        external: false
        targetPort: targetPort
        transport: 'auto'
        corsPolicy: {
          allowedOrigins: union([ 'https://portal.azure.com', 'https://ms.portal.azure.com' ], allowedOrigins)
        }
      } : null
      service: null
      registries: pullFromPrivateRegistry ? [
        {
          server: '${containerRegistryName}.azurecr.io'
          identity: userIdentity.id
        }
      ] : []
    }
    workloadProfileName: 'Consumption'
    template: {
      serviceBinds: null
      containers: [
        {
          image: !empty(imageName) ? imageName : 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          name: containerName
          env: env
          resources: {
            cpu: json(containerCpuCoreCount)
            memory: containerMemory
          }
        }
      ]
      scale: {
        minReplicas: containerMinReplicas
        maxReplicas: containerMaxReplicas
      }
      
    }
  }
}

//split fqdn into hostname and dns zone name
var fqdnParts = split(app.properties.configuration.ingress.fqdn, '.')
var hostname = fqdnParts[0]
var dnsZoneName = replace(app.properties.configuration.ingress.fqdn, '${hostname}.', '')


module privateDnsZone '../networking/dns.bicep' = {
  name: 'dns-deployment-app'
  params: {
    name: dnsZoneName
  }

}

module dnsEntry '../networking/dnsentry.bicep' = {
  name: 'dns-entry-app'
  params: {
    dnsZoneName: privateDnsZone.outputs.privateDnsZoneName
    hostname: hostname
    ipAddress: containerAppsEnvironment.properties.staticIp
  }
}

module apim '../apim/apim-backend.bicep' = {
  name: 'apim-backend'
  params: {
    apimServiceName: apimServiceName
    chargeBackApiBackendId: 'chargeback-backend'
    chargeBackAppUri: app.properties.configuration.ingress.fqdn
  }
}


resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-04-01-preview' existing = {
  name: containerAppsEnvironmentName
}

output defaultDomain string = containerAppsEnvironment.properties.defaultDomain
output identityPrincipalId string = userIdentity.id
output imageName string = imageName
output name string = app.name
