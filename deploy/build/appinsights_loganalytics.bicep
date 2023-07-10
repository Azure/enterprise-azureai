@minLength(3)
@maxLength(11)
param namePrefix string
param location string = resourceGroup().location

var uniqueAppInsightsName = '${namePrefix}${uniqueString(resourceGroup().id)}-ai'
var uniquelogAnalyticsWorkspaceName = '${namePrefix}${uniqueString(resourceGroup().id)}-ws'

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2020-10-01' = {
  name: uniquelogAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource appinsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  name: uniqueAppInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
  }
}

output appInsightsName string = appinsights.name
output appInsightsInstrKey string = appinsights.properties.InstrumentationKey
output appInsightsEndpoint string = appinsights.properties.ConnectionString
output logAnalyticsWorkspaceName string = logAnalyticsWorkspace.name
