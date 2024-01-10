namespace AzureAI.Proxy;
public class LogAnalyticsRecord
{
    public DateTime TimeGenerated { get; set; }
    public string Consumer { get; set; }
    public string Model { get; set; }
    public string ObjectType { get; set; }
    public int InputTokens { get; set; }
    public int OutputTokens { get; set; }
    public int TotalTokens { get; set; }
}