using Azure.Core;
using System.Text.Json;
using System.Text;
using Azure.Monitor.Ingestion;

namespace Azure.OpenAI.ChargebackProxy
{
    public static class LogAnalytics
    {
        public static async Task LogAsync(LogAnalyticsRecord record, LogsIngestionClient client, IConfiguration config)
        {
            try
            {
                Console.WriteLine("Writing logs....");
                var jsonContent = new List<LogAnalyticsRecord>();
                jsonContent.Add(record);
                
                //RBAC Monitoring Metrics Publisher needed
                RequestContent content = RequestContent.Create(JsonSerializer.Serialize(jsonContent));
                var ruleId = config.GetSection("AzureMonitor")["DataCollectionRuleImmutableId"].ToString();
                var stream = config.GetSection("AzureMonitor")["DataCollectionRuleStream"].ToString();
                Response response = await client.UploadAsync(ruleId, stream, content).ConfigureAwait(false);
                
            }
            catch (Exception ex)
            {
                Console.WriteLine($"Writing to LogAnalytics Failed: {ex.Message}");
            }

            
        }
    }
}
