param apimName string
param frontDoorId string

var frontDoorIdNamedValue = 'frontDoorId'

resource apim 'Microsoft.ApiManagement/service@2021-04-01-preview' existing = {
  name: apimName
}

resource apimFrontDoorIdNamedValue 'Microsoft.ApiManagement/service/namedValues@2022-08-01' = {
  name: 'apim-frontdoor-id-named-value'
  parent: apim
  properties: {
    displayName: frontDoorIdNamedValue
    secret: true
    value: frontDoorId
  }
}

resource globalPolicy 'Microsoft.ApiManagement/service/policies@2021-01-01-preview' = {
  parent: apim
  name: 'all-apis'
  properties: {
    value: loadTextContent('./policies/global_policy.xml')
    format: 'rawxml'
  }
}
