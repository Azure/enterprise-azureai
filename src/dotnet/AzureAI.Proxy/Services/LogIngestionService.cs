using Azure;
using Azure.Core;
using Azure.Monitor.Ingestion;
using System.Text.Json;

namespace AzureAI.Proxy.Services
{
    public class LogIngestionService : ILogIngestionService
    {
        private readonly IConfiguration _config;
        //private readonly IManagedIdentityService _managedIdentityService;
        private readonly LogsIngestionClient _logsIngestionClient;
        private readonly ILogger _logger;
        
        

        public LogIngestionService(
          //  IManagedIdentityService managedIdentityService, 
            LogsIngestionClient logsIngestionClient,
            IConfiguration config
,           ILogger<LogIngestionService> logger
            )
        {
            _config = config;
            _logsIngestionClient = logsIngestionClient;
            _logger = logger;
         }

        public async Task LogAsync(LogAnalyticsRecord record)
        {
            try
            {
                _logger.LogInformation("Writing logs...");
                var jsonContent = new List<LogAnalyticsRecord>();
                jsonContent.Add(record);

                //RBAC Monitoring Metrics Publisher needed
                RequestContent content = RequestContent.Create(JsonSerializer.Serialize(jsonContent));
                var ruleId = _config.GetSection("AzureMonitor")["DataCollectionRuleImmutableId"].ToString();
                var stream = _config.GetSection("AzureMonitor")["DataCollectionRuleStream"].ToString();

                Response response = await _logsIngestionClient.UploadAsync(ruleId, stream, content);

            }
            catch (Exception ex)
            {
                _logger.LogError($"Writing to LogAnalytics Failed: {ex.Message}");
            }


        }
    }
}
