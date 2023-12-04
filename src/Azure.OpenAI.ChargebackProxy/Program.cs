using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using Yarp.ReverseProxy.Transforms;
using TiktokenSharp;
using Azure.OpenAI.ChargebackProxy;
using System.Text.Json.Serialization.Metadata;
using AsyncAwaitBestPractices;
using Azure.Core;
using Azure.Identity;
using System.Runtime.CompilerServices;


string accessToken = "";

var builder = WebApplication.CreateBuilder(args);

var config = builder.Configuration;


DefaultAzureCredentialOptions defaultAzureCredentialOptions = new()
{
    TenantId = config["TenantId"]
};


TokenCredential managedIdentityCredential = new DefaultAzureCredential(defaultAzureCredentialOptions);
accessToken = await OpenAIAccessToken.GetAccessTokenAsync(managedIdentityCredential, CancellationToken.None);


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


            //now perform the analysis and create a message for eventhub
            LoggingOutputMessage msg = new LoggingOutputMessage();
            foreach (var header in responseContext.HttpContext.Response.Headers)
            {
                msg.ResponseHeaders.Add(header.Key, header.Value);
            }
            foreach (var header in responseContext.HttpContext.Request.Headers)
            {
                msg.RequestHeaders.Add(header.Key, header.Value);
            }

            //calculate token from the request
            msg = await CalculateInputTokens(responseContext.HttpContext.Request, msg).ConfigureAwait(false);
            //calculate token from the response
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


                        msg.Type = objectValue;

                        switch (objectValue)
                        {
                            case "chat.completion":
                                HandleChatCompletion(jsonNode, ref msg);
                                break;
                            case "chat.completion.chunk":
                                HandleChatCompletionChunck(jsonNode, ref msg);
                                break;
                            default:
                                break;
                        }
                    }
                }

            }

            //do not await, performance
            EventHub.SendAsync(msg, config, managedIdentityCredential).SafeFireAndForget();
            
            //return;



        });
    });


var app = builder.Build();


app.MapReverseProxy();

app.Run();



static void HandleChatCompletion(JsonNode jsonNode, ref LoggingOutputMessage msg)
{
    //read tokens from responsebody - not streaming, so data is just there
    var usage = jsonNode["usage"];
    var tokens = int.Parse(usage["total_tokens"].ToString());
    msg.Tokens = tokens;
    msg.BodyContent.Add(jsonNode);

}

static void HandleChatCompletionChunck(JsonNode jsonNode, ref LoggingOutputMessage msg)
{
    //calculate tokens based on the content...we need a tokenizer to calculate
    var modelName = jsonNode["model"].ToString();
    var choices = jsonNode["choices"];
    var delta = choices[0]["delta"];
    var content = delta["content"];
    //for now every response is one token
    if (content != null)
    {

        msg.Tokens += GetTokensFromString(content.ToString(), modelName);
        msg.BodyContent.Add(jsonNode);
    }
}

static void HandleError(JsonNode jsonNode)
{
    //do nothing
}

static async Task<LoggingOutputMessage> CalculateInputTokens(HttpRequest request, LoggingOutputMessage msg)
{
    //Rewind to first position to read the stream again
    request.Body.Position = 0;

    StreamReader reader = new StreamReader(request.Body, true);
    string bodyText = reader.ReadToEnd();
    Console.WriteLine(bodyText);

    JsonNode jsonNode = JsonSerializer.Deserialize<JsonNode>(bodyText, CreateDefaultOptions());
    var modelName = jsonNode["model"].ToString();
    var messages = jsonNode["messages"].AsArray();
    foreach (var message in messages)
    {
        var content = message["content"].ToString();
        //calculate tokens here using a tokenizer....use length for now....
        msg.Tokens += GetTokensFromString(content, modelName);
    }



    return msg;


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