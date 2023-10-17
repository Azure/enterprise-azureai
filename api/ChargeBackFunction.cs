using System;
using System.Text;
using Newtonsoft.Json;
using Azure.Messaging.EventHubs;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using Microsoft.ApplicationInsights;
using Microsoft.ApplicationInsights.Extensibility;

namespace MyFunctionApp
{
    public class ChargeBackFunction
    {
        private readonly ILogger<ChargeBackFunction> _logger;

        public ChargeBackFunction(ILogger<ChargeBackFunction> logger)
        {
            _logger = logger;
        }

        [Function(nameof(ChargeBackFunction))]
        public static async Task Run(
            [EventHubTrigger("openai-chargeback-hub", Connection = "EVENTHUB_CONNECTION_STRING")] EventData[] eventHubMessages,            
            ILogger logger)
        {
            logger.LogInformation("Chargeback function triggered");
            try
            {
                foreach (var message in eventHubMessages)
                {
                    string messageBody = Encoding.UTF8.GetString(message.EventBody.ToArray());

                    logger.LogInformation($"Chargeback Data {messageBody}");

                    var telemetryConfiguration = new TelemetryConfiguration
                    {
                        ConnectionString = Environment.GetEnvironmentVariable("APPLICATIONINSIGHTS_CONNECTION_STRING")
                    };
                    var telemetryClient = new TelemetryClient(telemetryConfiguration);
                    telemetryClient.TrackEvent("Function called with Chargeback Data", JsonConvert.DeserializeObject<Dictionary<string, string>>(messageBody));

                    await Task.FromResult(true);
                    telemetryClient.Flush();
                }
            }
            catch (Exception ex)
            {
                logger.LogError($"Something went wrong. Exception thrown: {ex.Message}");
            }
        }
    }
}
