using Azure.Core;
using Azure.Identity;
using Azure.Monitor.Ingestion;

namespace Azure.OpenAI.ChargebackProxy.Services
{
    public interface ILogIngestionService
    {
        Task LogAsync(LogAnalyticsRecord record);
    }
}
