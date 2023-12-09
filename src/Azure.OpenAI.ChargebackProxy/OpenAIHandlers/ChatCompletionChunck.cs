using System.Text.Json.Nodes;

namespace Azure.OpenAI.ChargebackProxy.OpenAIHandlers
{
    public static class ChatCompletionChunck
    {
        public static void Handle(JsonNode jsonNode, ref LogAnalyticsRecord record)
        {
            //calculate tokens based on the content...we need a tokenizer to calculate
            var modelName = jsonNode["model"].ToString();
            record.Model = modelName;
            var choices = jsonNode["choices"];
            var delta = choices[0]["delta"];
            var content = delta["content"];
            //calculate tokens used
            if (content != null)
            {
                record.OutputTokens += Tokens.GetTokensFromString(content.ToString(), modelName);

            }
        }
    }
}
