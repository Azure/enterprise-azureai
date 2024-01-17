using Azure.Monitor.OpenTelemetry.AspNetCore;
using AzureAI.Proxy.ReverseProxy;
using AzureAI.Proxy.Services;
using OpenTelemetry.Resources;
using OpenTelemetry.Trace;
using Yarp.ReverseProxy.Health;


var builder = WebApplication.CreateBuilder(args);

//Application Insights
var instanceId = Environment.GetEnvironmentVariable("CONTAINER_APP_REPLICA_NAME");
if (instanceId == null)
{
    instanceId = "local";
}

var resourceAttributes = new Dictionary<string, object> {
    { "service.name", "Proxy" },
    { "service.namespace", "AzureAI" },
    { "service.instance.id", instanceId }
};

builder.Services.AddOpenTelemetry().UseAzureMonitor();
builder.Services.ConfigureOpenTelemetryTracerProvider((sp, builder) =>
    builder.ConfigureResource(resourceBuilder =>
        resourceBuilder.AddAttributes(resourceAttributes)));


//Managed Identity Service
builder.Services.AddSingleton<IManagedIdentityService, ManagedIdentityService>();
var managedIdentityService = builder.Services.BuildServiceProvider().GetService<IManagedIdentityService>();

//Azure App Configuration
builder.Configuration.AddAzureAppConfiguration(options =>
    options.Connect(
                new Uri(builder.Configuration["APPCONFIG_ENDPOINT"]),
                managedIdentityService.GetTokenCredential()
            )
);

var config = builder.Configuration;

//Log Ingestion for charge back data
builder.Services.AddSingleton<ILogIngestionService, LogIngestionService>((ctx) =>
{
    var managedIdentityService = ctx.GetService<IManagedIdentityService>();
    ILogger logger = builder.Services.BuildServiceProvider().GetRequiredService<ILogger<LogIngestionService>>();
    return new LogIngestionService(managedIdentityService, config, logger);
});

//Setup Reverse Proxy
var proxyConfig = new ProxyConfiguration(config["AzureAIProxy:ProxyConfig"]);
var routes = proxyConfig.GetRoutes();
var clusters = proxyConfig.GetClusters();

builder.Services.AddSingleton<IPassiveHealthCheckPolicy, ThrottlingHealthPolicy>();

builder.Services.AddReverseProxy()
    .LoadFromMemory(routes, clusters)
    .ConfigureHttpClient((sp, options) =>
    {
        //decompress the Response so we can read it
        options.AutomaticDecompression = System.Net.DecompressionMethods.All;
    })
    .AddTransforms<OpenAIChargebackTransformProvider>();

builder.Services.AddHealthChecks();

var app = builder.Build();

app.MapHealthChecks("/health");

app.MapReverseProxy(m =>
{
    m.UseMiddleware<RetryMiddleware>();
    m.UsePassiveHealthChecks();
});

app.Run();









