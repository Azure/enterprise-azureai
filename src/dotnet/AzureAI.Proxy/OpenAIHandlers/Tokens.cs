using System.Text.Json.Nodes;
using System.Text.Json;
using TiktokenSharp;

namespace AzureAI.Proxy.OpenAIHandlers;

public static class Tokens
{
    public static int GetTokensFromString(string str, string modelName)
    {
        if (modelName.Contains("gpt-35"))
            modelName = modelName.Replace("35", "3.5");

        var encodingManager = TikToken.EncodingForModel(modelName);
        var encoding = encodingManager.Encode(str);
        int nrTokens = encoding.Count();
        return nrTokens;
    }

    public static LogAnalyticsRecord CalculateChatInputTokens(string requestBody, LogAnalyticsRecord record)
    {
        JsonNode jsonNode = JsonSerializer.Deserialize<JsonNode>(requestBody);
        var modelName = jsonNode["model"].ToString();

        record.Model = modelName;

        var messages = jsonNode["messages"].AsArray();
        foreach (var message in messages)
        {
            var content = message["content"].ToString();
            //calculate tokens using a tokenizer.
            record.InputTokens += GetTokensFromString(content, modelName);
        }

        return record;
    }
}
