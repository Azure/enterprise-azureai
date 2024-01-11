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

    public static LogAnalyticsRecord CalculateChatInputTokens(HttpRequest request, LogAnalyticsRecord record)
    {
        //Rewind to first position to read the stream again
        request.Body.Position = 0;

        StreamReader reader = new StreamReader(request.Body, true);
        string bodyText = reader.ReadToEnd();
 
        JsonNode jsonNode = JsonSerializer.Deserialize<JsonNode>(bodyText);
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
