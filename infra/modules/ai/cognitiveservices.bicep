param name string
param location string = resourceGroup().location
param tags object = {}

param customSubDomainName string = name
param deployments array = []
param kind string = 'OpenAI'

param disableLocalAuth bool = true // Only allow access to Azure OpenAI via managed identity
param publicNetworkAccess string = 'Disabled'
param sku object = {
  name: 'S0'
}

param deploymentScriptIdentityName string
param chargeBackManagedIdentityName string
param logAnalyticsWorkspaceId string

//Private Endpoint settings
param openAiPrivateEndpointName string
param privateEndpointLocation string = location
param vNetName string
param privateEndpointSubnetName string
param openAiDnsZoneName string

// Cognitive Services OpenAI User
var roleDefinitionResourceId = '/providers/Microsoft.Authorization/roleDefinitions/5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
// Cognitive Services OpenAI Contributor
var roleDefinitionDeploymentScriptResourceId = '/providers/Microsoft.Authorization/roleDefinitions/a001fd3d-188f-4b5d-821b-7da978bf7442'

// resource managedIdentityApim 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
//   name: apimManagedIdentityName
// }

resource managedIdentityChargeBack 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: chargeBackManagedIdentityName
}

resource managedIdentityDeploymentScript 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: deploymentScriptIdentityName
}

resource account 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: name
  location: location
  tags: union(tags, { 'azd-service-name': name })
  kind: kind
  properties: {
    disableLocalAuth: disableLocalAuth 
    customSubDomainName: customSubDomainName
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: 'Deny'
    }
  }
  sku: sku
}


resource roleAssignmentDeploymentScript 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: account
  name: guid(managedIdentityDeploymentScript.id, roleDefinitionDeploymentScriptResourceId, account.name)
  properties: {
    roleDefinitionId: roleDefinitionDeploymentScriptResourceId
    principalId: managedIdentityDeploymentScript.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

param raiPolicies array = [
  {
    name: 'default-policy'
    payload: replace(loadTextContent('rai_policies/default-with-jailbreak-detection.json'), '"', '\\"')
  }
  {
    name: 'low-filtering-policy'
    payload: replace(loadTextContent('rai_policies/low-filtering-policy.json'), '"', '\\"')
  }
]




resource deploymentScript 'Microsoft.Resources/deploymentScripts@2023-08-01' = [for raiPolicy in raiPolicies: {
  dependsOn: [
    roleAssignmentDeploymentScript
  ]
  name: 'create_rai_policy__${raiPolicy.name}_${account.name}'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentityDeploymentScript.id}': {}
    }
  }
  properties: {
    azCliVersion: '2.47.0'
    scriptContent: 'az rest --method put --url ${environment().resourceManager}/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.CognitiveServices/accounts/${account.name}/raiPolicies/${raiPolicy.name}?api-version=2023-10-01-preview --debug --body "${raiPolicy.payload}"'
    cleanupPreference: 'OnExpiration'
    retentionInterval: 'PT1H'
    forceUpdateTag: guid(raiPolicy.payload)
  }
}]

@batchSize(1)
resource deployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = [for deployment in deployments: {
  parent: account
  name: deployment.name
  properties: {
    model: deployment.model
    raiPolicyName: contains(deployment, 'raiPolicyName') ? deployment.raiPolicyName : null
  }
  sku: contains(deployment, 'sku') ? deployment.sku : {
    name: 'Standard'
    capacity: 20
  }
}]

module privateEndpoint '../networking/private-endpoint.bicep' = {
  name: '${account.name}-privateEndpoint-deployment'
  params: {
    groupIds: [
      'account'
    ]
    dnsZoneName: openAiDnsZoneName
    name: openAiPrivateEndpointName
    subnetName: privateEndpointSubnetName
    privateLinkServiceId: account.id
    vNetName: vNetName
    location: privateEndpointLocation
  }
}



resource roleAssignmentChargeBack 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: account
  name: guid(managedIdentityChargeBack.id, roleDefinitionResourceId, account.name)
  properties: {
    roleDefinitionId: roleDefinitionResourceId
    principalId: managedIdentityChargeBack.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'LogToLogAnalytics'
  scope: account
  properties: {
    workspaceId: logAnalyticsWorkspaceId
    logs: []
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true 
      }
    ]
  }
}

output openAiName string = account.name
output openAiEndpointUri string = '${account.properties.endpoint}openai/'
output openAIEndpointUriRaw string = account.properties.endpoint
