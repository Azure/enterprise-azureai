using System.Text.Json.Nodes;
using AzureAI.Proxy.Models;

namespace AzureAI.Proxy.OpenAIHandlers
{
    public static class Usage
    {
        public static void Handle(JsonNode jsonNode, ref LogAnalyticsRecord record)
        {
            //read tokens from responsebody - not streaming, so data is just there
            var modelName = jsonNode["model"].ToString();
            record.Model = modelName;
            var usage = jsonNode["usage"];
            if (usage["completion_tokens"] != null)
            {
                record.OutputTokens = int.Parse(usage["completion_tokens"].ToString());
            }
            else
            {
                record.OutputTokens = 0;
            }
            record.InputTokens = int.Parse(usage["prompt_tokens"].ToString());
        }
    }
}
