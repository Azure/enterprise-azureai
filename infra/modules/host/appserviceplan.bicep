param name string
param location string = resourceGroup().location
param tags object = {}

param kind string = ''
param reserved bool = true
param sku object

resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  sku: sku
  kind: kind
  properties: {
    reserved: reserved
  }
}

output appServicePlanId string = appServicePlan.id
output appServicePlanName string = appServicePlan.name
