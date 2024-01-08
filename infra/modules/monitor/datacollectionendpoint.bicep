param name string
param location string


resource dataCollectionEndpoint 'Microsoft.Insights/dataCollectionEndpoints@2022-06-01' = {
  name: name
  location: location
  properties:{
    description: 'Data Collection Endpoint for Azure OpenAI Chargeback'
  }

}

output dataCollectionEndpointResourceId string = dataCollectionEndpoint.id
output dataCollectionEndPointLogIngestionUrl string = dataCollectionEndpoint.properties.logsIngestion.endpoint

