targetScope = 'resourceGroup'

param serviceBusNamespaceName string
param serviceBusTopicName string
param serviceBusSubODSName string
param serviceBusSubUpdName string

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2017-04-01' existing = {
  name: serviceBusNamespaceName
}

resource serviceBusTopic 'Microsoft.ServiceBus/namespaces/topics@2021-11-01' = {
  name: '${serviceBusNamespace.name}/${serviceBusTopicName}'
  properties: {}
}

resource serviceBusSubODS 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2021-11-01' = {
  name: '${serviceBusNamespace.name}/${serviceBusTopicName}/${serviceBusSubODSName}'
  properties: {}
  dependsOn: [
    serviceBusTopic
  ]
}

resource serviceBusSubUpd 'Microsoft.ServiceBus/namespaces/topics/subscriptions@2021-11-01' = {
  name: '${serviceBusNamespace.name}/${serviceBusTopicName}/${serviceBusSubUpdName}'
  properties: {}
  dependsOn: [
    serviceBusTopic
  ]
}
