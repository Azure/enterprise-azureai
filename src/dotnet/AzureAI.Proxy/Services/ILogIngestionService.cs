namespace AzureAI.Proxy.Services
{
    public interface ILogIngestionService
    {
        Task LogAsync(LogAnalyticsRecord record);
    }
}
