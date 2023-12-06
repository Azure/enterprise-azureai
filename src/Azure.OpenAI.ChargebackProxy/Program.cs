using AsyncAwaitBestPractices;
using Azure;
using Azure.Core;
using Azure.Identity;
using Azure.Monitor.Ingestion;
using Azure.OpenAI.ChargebackProxy;
using System.Diagnostics.CodeAnalysis;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.Json.Serialization.Metadata;
using TiktokenSharp;
using Yarp.ReverseProxy.Transforms;

string accessToken = "";

var builder = WebApplication.CreateBuilder(args);

var config = builder.Configuration;


DefaultAzureCredentialOptions defaultAzureCredentialOptions = new()
{
    
    TenantId = config["TenantId"]
};


TokenCredential managedIdentityCredential = new DefaultAzureCredential(defaultAzureCredentialOptions);
accessToken = await OpenAIAccessToken.GetAccessTokenAsync(managedIdentityCredential, CancellationToken.None);

var endpoint = new Uri(config.GetSection("AzureMonitor")["DataCollectionEndpoint"].ToString());
var logsIngestionClient = new LogsIngestionClient(endpoint, managedIdentityCredential);




builder.Services.AddReverseProxy()
    .LoadFromConfig(builder.Configuration.GetSection("ReverseProxy"))
    .ConfigureHttpClient((sp, options) =>
    {
        //decompress the Response so we can read it
        options.AutomaticDecompression = System.Net.DecompressionMethods.All;

       

    })
    .AddTransforms(context =>
    {
        context.AddRequestTransform(async requestContext => {
            //enable buffering allows us to read the requestbody twice (one for forwarding, one for analysis)
            requestContext.HttpContext.Request.EnableBuffering();

            //check accessToken before replacing the Auth Header
            if (OpenAIAccessToken.IsTokenExpired(accessToken, config["TenantId"]))
            {
                accessToken = await OpenAIAccessToken.GetAccessTokenAsync(managedIdentityCredential, CancellationToken.None);
            }

            //replace auth header with the accesstoken of the managed indentity of the proxy
            requestContext.ProxyRequest.Headers.Remove("api-key");
            requestContext.ProxyRequest.Headers.Add("Authorization", $"Bearer {accessToken}");

        });
        context.AddResponseTransform(async responseContext =>
        {

            var originalStream = await responseContext.ProxyResponse.Content.ReadAsStreamAsync();
            string capturedBody = "";

            // Buffer for reading chunks
            byte[] buffer = new byte[8192];
            int bytesRead;

            // Read, inspect, and write the data in chunks - this is especially needed for streaming content
            while ((bytesRead = await originalStream.ReadAsync(buffer, 0, buffer.Length)) > 0)
            {
                // Convert the chunk to a string for inspection
                var chunk = Encoding.UTF8.GetString(buffer, 0, bytesRead);

                capturedBody += chunk;

                // Write the unmodified chunk back to the response
                await responseContext.HttpContext.Response.Body.WriteAsync(buffer, 0, bytesRead);
            }


            //now perform the analysis and create a log record
            var record = new LogAnalyticsRecord();
            record.TimeGenerated = DateTime.UtcNow;
            record.ApiKey = responseContext.HttpContext.Request.Headers["api-key"].ToString();
            if (responseContext.HttpContext.Request.Headers["X-Consumer"].ToString() != "")
            {
                record.Consumer = responseContext.HttpContext.Request.Headers["X-Consumer"].ToString();
            }
            else
            {
                record.Consumer = "Unknown";
            }


            
            bool firstChunck = true;
            var chunks = capturedBody.Split("data:");
            foreach (var chunk in chunks)
            {
                var trimmedChunck = chunk.Trim();
                if (trimmedChunck != "" && trimmedChunck != "[DONE]")
                {

                    JsonNode jsonNode = JsonSerializer.Deserialize<JsonNode>(trimmedChunck, CreateDefaultOptions());
                    if (jsonNode["error"] is not null)
                    {
                        HandleError(jsonNode);
                    }
                    else
                    {
                        string objectValue = jsonNode["object"].ToString();

                       

                        switch (objectValue)
                        {
                            case "chat.completion":
                                HandleUsage(jsonNode, ref record);
                                record.ObjectType = objectValue;
                                break;
                            case "chat.completion.chunk":
                                if (firstChunck)
                                {
                                    record = await CalculateChatInputTokens(responseContext.HttpContext.Request, record).ConfigureAwait(false);
                                    record.ObjectType = objectValue;
                                    firstChunck = false;
                                }
                                HandleChatCompletionChunck(jsonNode, ref record);
                                break;
                            case "list":
                                if (jsonNode["data"][0]["object"].ToString() == "embedding")
                                {
                                    record.ObjectType = jsonNode["data"][0]["object"].ToString();
                                    //it's an embedding
                                    HandleUsage(jsonNode, ref record);
                                }
                                break;
                            default:
                                break;
                        }
                    }
                }

            }

            record.TotalTokens = record.InputTokens + record.OutputTokens;

            if (bool.Parse(config["OutputToEventHub"].ToString()))
            {
                EventHub.SendAsync(record, config, managedIdentityCredential).SafeFireAndForget();
            }
            
           
            LogAnalytics.LogAsync(record, logsIngestionClient, config).SafeFireAndForget();
         });
    });


var app = builder.Build();


app.MapReverseProxy();

app.Run();



static void HandleUsage(JsonNode jsonNode, ref LogAnalyticsRecord record)
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

static void HandleChatCompletionChunck(JsonNode jsonNode, ref LogAnalyticsRecord record)
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
        record.OutputTokens += GetTokensFromString(content.ToString(), modelName);
       
    }
}

static void HandleError(JsonNode jsonNode)
{
    //do nothing yet....figure out later
}

static async Task<LogAnalyticsRecord> CalculateChatInputTokens(HttpRequest request, LogAnalyticsRecord record)
{
    //Rewind to first position to read the stream again
    request.Body.Position = 0;

    StreamReader reader = new StreamReader(request.Body, true);
    string bodyText = reader.ReadToEnd();
    //Console.WriteLine(bodyText);

    JsonNode jsonNode = JsonSerializer.Deserialize<JsonNode>(bodyText, CreateDefaultOptions());
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

static int GetTokensFromString(string str, string modelName)
{
    var encodingManager = TikToken.EncodingForModel(modelName);
    var encoding = encodingManager.Encode(str);
    int nrTokens = encoding.Count();
    return nrTokens;
}

static JsonSerializerOptions CreateDefaultOptions()
{
    return new()
    {
        TypeInfoResolver = new DefaultJsonTypeInfoResolver()
            
    };
}