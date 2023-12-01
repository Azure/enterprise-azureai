using System.Text.Json.Nodes;
using System.Text.Json.Serialization;

namespace Azure.OpenAI.ChargebackProxy;

public class LoggingOutputMessage
{
    public int Tokens { get; set; }
    public string Type { get; set; }
    public Dictionary<string, string> RequestHeaders { get; set; } = new Dictionary<string, string>();
    public Dictionary<string, string> ResponseHeaders { get; set; } = new Dictionary<string, string>();
    public List<JsonNode> BodyContent { get; set; } = new List<JsonNode>();

}

[JsonSourceGenerationOptions(WriteIndented = true)]
[JsonSerializable(typeof(LoggingOutputMessage))]
internal partial class SourceGenerationContext : JsonSerializerContext
{
}