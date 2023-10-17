param name string
param applicationInsightsName string
//param location string = resourceGroup().location
param tags object = {}

param apimGatewayUrl string

var gatewayContent = format(
  '''
# OpenAI API Gateway
Replace your OpenAI API endpoint with the following values.

**Endpoint URL**: `{0}`

**Endpoint Key**: Navigate to your API Management instance -> Subscription keys

**Endpoint Key**:
- Navigate to your resource group where you deployed this script
- Find your API Management instance\n- Subscription keys -> Show / Copy keys


# Workbooks and visualizations
- Navigate to your resource group where you deployed this script
- Open the service named OpenAI Workbook"


''', apimGatewayUrl)

resource dashboard 'Microsoft.Portal/dashboards@2020-09-01-preview' = {
  name: name
  location: 'global'
  tags: union(tags, { 'azd-service-name': name })
  properties: {
    lenses: [
      {
        order: 0
        parts: [
          {
            position: {
              x: 0
              y: 0
              rowSpan: 6
              colSpan: 9
            }
            metadata: {
              inputs: []
              type: 'Extension/HubsExtension/PartType/MarkdownPart'
              settings: {
                content: {
                  settings: {
                    content: gatewayContent
                  }
                }
              }
            }
          }
        ]
      }
    ]
  }
}

resource applicationInsights 'Microsoft.Insights/components@2020-02-02' existing = {
  name: applicationInsightsName
}
