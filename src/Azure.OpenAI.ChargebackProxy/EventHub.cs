using Azure.Messaging.EventHubs.Producer;

namespace Azure.OpenAI.ChargebackProxy;
using Azure.Identity;
using Azure.Messaging.EventHubs;
using System.Text;
using System.Text.Json;
using System.Text.Json.Serialization;

public static class EventHub
{
 

    public async static Task SendAsync(LoggingOutputMessage msgBody, IConfiguration config)
    {
        DefaultAzureCredentialOptions options = new DefaultAzureCredentialOptions();
        options.TenantId = "16b3c013-d300-468d-ac64-7eda0820b6d3";

        EventHubProducerClient producerClient = new EventHubProducerClient(
        config["EventhubNameSpace"],
        config["EventhubName"],
        new DefaultAzureCredential());

        EventDataBatch eventBatch = await producerClient.CreateBatchAsync();

        var message = new EventData(Encoding.UTF8.GetBytes(JsonSerializer.Serialize(msgBody, SourceGenerationContext.Default.LoggingOutputMessage)));

        message.Properties.Add("source", "Azure.OpenAI.ChargebackProxy");
        
        eventBatch.TryAdd(message);
        try
        {
            await producerClient.SendAsync(eventBatch);
        }
        catch (Exception ex)
        {
            Console.WriteLine($"error sending to Eventhub: {ex.Message}");
        }

        
    }

    

}
