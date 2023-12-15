param name string
param location string = resourceGroup().location
param tags object = {}

@description('Name of the Application Insights resource')
param applicationInsightsName string = ''

@description('Specifies if Dapr is enabled')
param daprEnabled bool = false

@description('Name of the Log Analytics workspace')
param logAnalyticsWorkspaceName string

param vnetName string
param subnetName string

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-04-01-preview' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    daprAIInstrumentationKey: daprEnabled && !empty(applicationInsightsName) ? applicationInsights.properties.InstrumentationKey : ''
    vnetConfiguration: {
      internal: true
      infrastructureSubnetId: resourceId('Microsoft.Network/VirtualNetworks/subnets', vnetName, subnetName)
    }
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
  }
}

module privateDnsZone '../networking/dns.bicep' = {
  name: 'dns-deployment-app'
  params: {
    name: containerAppsEnvironment.properties.defaultDomain
  }
}

module dnsEntry '../networking/dnsentry.bicep' = {
  name: 'dns-entry-env'
  params: {
    dnsZoneName: privateDnsZone.outputs.privateDnsZoneName
    hostname: '*'
    ipAddress: containerAppsEnvironment.properties.staticIp
  }
}

module privateDnsZoneLink '../networking/dnsvirtualnetworklink.bicep' = {
  name: 'dns-vnetlink'
  dependsOn: [
    dnsEntry
  ]
  params: {
    dnsZoneName: privateDnsZone.outputs.privateDnsZoneName
    vnetName: vnetName
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = if (daprEnabled && !empty(applicationInsightsName)) {
  name: applicationInsightsName
}

output defaultDomain string = containerAppsEnvironment.properties.defaultDomain
output id string = containerAppsEnvironment.id
output name string = containerAppsEnvironment.name
