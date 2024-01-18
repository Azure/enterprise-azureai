using AsyncAwaitBestPractices;
using Azure.Core;
using AzureAI.Proxy.OpenAIHandlers;
using AzureAI.Proxy.Services;
using System.Net;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using Yarp.ReverseProxy.Model;
using Yarp.ReverseProxy.Transforms;
using Yarp.ReverseProxy.Transforms.Builder;

namespace AzureAI.Proxy.ReverseProxy;

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
        _logIngestionService = logIngestionService;
               
        _managedIdentityCredential = _managedIdentityService.GetTokenCredential();

    }

    public void ValidateRoute(TransformRouteValidationContext context) { return; }

    public void ValidateCluster(TransformClusterValidationContext context) { return; }
    
    public void Apply(TransformBuilderContext context)
    {
        context.AddRequestTransform(async requestContext => {
            //enable buffering allows us to read the requestbody twice (one for forwarding, one for analysis)
            requestContext.HttpContext.Request.EnableBuffering();

            //check accessToken before replacing the Auth Header
            if (String.IsNullOrEmpty(accessToken) || OpenAIAccessToken.IsTokenExpired(accessToken))
            {
                accessToken = await OpenAIAccessToken.GetAccessTokenAsync(_managedIdentityCredential, CancellationToken.None);
            }

            //replace auth header with the accesstoken of the managed indentity of the proxy
            requestContext.ProxyRequest.Headers.Remove("api-key");
            requestContext.ProxyRequest.Headers.Remove("Authorization");
            requestContext.ProxyRequest.Headers.Add("Authorization", $"Bearer {accessToken}");

        });
        context.AddResponseTransform(async responseContext =>
        {
            //hit 429 or internal server error, can we retry on another node?
            if (responseContext.ProxyResponse?.StatusCode is HttpStatusCode.TooManyRequests
                or >= HttpStatusCode.InternalServerError)
            {
                var reverseProxyContext = responseContext.HttpContext.GetReverseProxyFeature();

                var canRetry = reverseProxyContext.AllDestinations.Count(m =>
                    m.Health.Passive != DestinationHealth.Unhealthy
                    && m.DestinationId != reverseProxyContext?.ProxiedDestination?.DestinationId) > 0;

                if (canRetry)
                {
                    // Suppress the response body from being written when we will retry
                    responseContext.SuppressResponseBody = true;
                }
            }
            else
            {
                var originalStream = await responseContext.ProxyResponse.Content.ReadAsStreamAsync();
                var stringBuilder = new StringBuilder();

                // Buffer for reading chunks
                byte[] buffer = new byte[8192];
                int bytesRead;

                // Read, inspect, and write the data in chunks - this is especially needed for streaming content
                while ((bytesRead = await originalStream.ReadAsync(buffer, 0, buffer.Length)) > 0)
                {
                    // Convert the chunk to a string for inspection
                    var chunk = Encoding.UTF8.GetString(buffer, 0, bytesRead);

                    stringBuilder.Append(chunk);

                    // Write the unmodified chunk back to the response
                    await responseContext.HttpContext.Response.Body.WriteAsync(buffer, 0, bytesRead);
                }

                //flush any remaining content to the client
                await responseContext.HttpContext.Response.CompleteAsync();

                //now perform the analysis and create a log record
                var record = new LogAnalyticsRecord();
                record.TimeGenerated = DateTime.UtcNow;

                if (responseContext.HttpContext.Request.Headers["X-Consumer"].ToString() != "")
                {
                    record.Consumer = responseContext.HttpContext.Request.Headers["X-Consumer"].ToString();
                }
                else
                {
                    record.Consumer = "Unknown Consumer";
                }

                bool firstChunck = true;
                var capturedBody = stringBuilder.ToString();
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
                _logIngestionService.LogAsync(record).SafeFireAndForget();
            }
        });
    }
}
