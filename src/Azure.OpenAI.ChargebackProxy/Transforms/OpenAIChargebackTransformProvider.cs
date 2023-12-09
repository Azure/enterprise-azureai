using System.Text.Json.Nodes;
using System.Text.Json;
using System.Text;
using Yarp.ReverseProxy.Transforms;
using Yarp.ReverseProxy.Transforms.Builder;
using Azure.Core;
using Azure.OpenAI.ChargebackProxy.OpenAIHandlers;
using Azure.Monitor.Ingestion;
using AsyncAwaitBestPractices;
using Azure.OpenAI.ChargebackProxy.Services;
using Azure.Identity;

namespace Azure.OpenAI.ChargebackProxy.Transforms;

internal class OpenAIChargebackTransformProvider : ITransformProvider
{
    private readonly IConfiguration _config;
    private readonly IManagedIdentityService _managedIdentityService;
    private readonly ILogIngestionService _logIngestionService;
   
    private string accessToken = "";

    private TokenCredential _managedIdentityCredential;

    public OpenAIChargebackTransformProvider(
        IConfiguration config, 
       
        IManagedIdentityService managedIdentityService,
        ILogIngestionService logIngestionService)
    {
        _config = config;
        _managedIdentityService = managedIdentityService;
        

        DefaultAzureCredentialOptions defaultAzureCredentialOptions = new()
        {
            TenantId = config["TenantId"]
        };
        _managedIdentityCredential = _managedIdentityService.GetTokenCredential(defaultAzureCredentialOptions);

    }

    public void ValidateRoute(TransformRouteValidationContext context) { return; }

    public void ValidateCluster(TransformClusterValidationContext context) { return; }
    
    public void Apply(TransformBuilderContext context)
    {
        context.AddRequestTransform(async requestContext => {
            //enable buffering allows us to read the requestbody twice (one for forwarding, one for analysis)
            requestContext.HttpContext.Request.EnableBuffering();

            //check accessToken before replacing the Auth Header
            if (String.IsNullOrEmpty(accessToken) || OpenAIAccessToken.IsTokenExpired(accessToken, _config["TenantId"]))
            {
                accessToken = await OpenAIAccessToken.GetAccessTokenAsync(_managedIdentityCredential, CancellationToken.None);
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

            //flush any remaining content to the client
            await responseContext.HttpContext.Response.CompleteAsync();


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

                    JsonNode jsonNode = JsonSerializer.Deserialize<JsonNode>(trimmedChunck);
                    if (jsonNode["error"] is not null)
                    {
                        Error.Handle(jsonNode);
                    }
                    else
                    {
                        string objectValue = jsonNode["object"].ToString();



                        switch (objectValue)
                        {
                            case "chat.completion":
                                Usage.Handle(jsonNode, ref record);
                                record.ObjectType = objectValue;
                                break;
                            case "chat.completion.chunk":
                                if (firstChunck)
                                {
                                    record = Tokens.CalculateChatInputTokens(responseContext.HttpContext.Request, record);
                                    record.ObjectType = objectValue;
                                    firstChunck = false;
                                }
                                ChatCompletionChunck.Handle(jsonNode, ref record);
                                break;
                            case "list":
                                if (jsonNode["data"][0]["object"].ToString() == "embedding")
                                {
                                    record.ObjectType = jsonNode["data"][0]["object"].ToString();
                                    //it's an embedding
                                    Usage.Handle(jsonNode, ref record);
                                }
                                break;
                            default:
                                break;
                        }
                    }
                }

            }

            record.TotalTokens = record.InputTokens + record.OutputTokens;

            if (bool.Parse(_config["OutputToEventHub"].ToString()))
            {
                EventHub.SendAsync(record, _config, _managedIdentityCredential).SafeFireAndForget();
            }


            //_logIngestionService.LogAsync(record).SafeFireAndForget();
        });
    }
}
