using Azure.Core;
using Azure.Identity;
using Azure.Monitor.Ingestion;
using System.Text.Json;

namespace Azure.OpenAI.ChargebackProxy.Services
{
    public class LogIngestionService : ILogIngestionService
    {
        private readonly IConfiguration _config;
        private readonly IManagedIdentityService _managedIdentityService;
        private readonly ILogger _logger;
        private TokenCredential _credential;
        private LogsIngestionClient _logsIngestionClient;

        public LogIngestionService(
            IManagedIdentityService managedIdentityService, 
            IConfiguration config
,           ILogger logger
            )
        {
            _config = config;
            DefaultAzureCredentialOptions defaultAzureCredentialOptions = new()
            {
                TenantId = _config["TenantId"]
            };

            _credential = managedIdentityService.GetTokenCredential(defaultAzureCredentialOptions);
            var endpoint = new Uri(_config.GetSection("AzureMonitor")["DataCollectionEndpoint"].ToString());


            _logsIngestionClient = new LogsIngestionClient(endpoint, _credential);
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
