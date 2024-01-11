using AzureAI.Proxy.ReverseProxy;
using AzureAI.Proxy.Services;
using System.Reflection.Metadata.Ecma335;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSingleton<IManagedIdentityService, ManagedIdentityService>();

var managedIdentityService = builder.Services.BuildServiceProvider().GetService<IManagedIdentityService>();


builder.Configuration.AddAzureAppConfiguration(options =>
    options.Connect(
        new Uri(builder.Configuration["APPCONFIG_ENDPOINT"]),
        managedIdentityService.GetTokenCredential()));

var config = builder.Configuration;

builder.Services.AddSingleton<ILogIngestionService, LogIngestionService>((ctx) =>
{
    var managedIdentityService = ctx.GetService<IManagedIdentityService>();
    ILogger logger = builder.Services.BuildServiceProvider().GetRequiredService<ILogger<LogIngestionService>>();
    return new LogIngestionService(managedIdentityService, config, logger);
});

var routes = Routes.GetRoutes();
var clusters = Clusters.GetClusterConfig(config);

builder.Services.AddReverseProxy()
    .LoadFromMemory(routes, clusters)
    .ConfigureHttpClient((sp, options) =>
    {
        //decompress the Response so we can read it
        options.AutomaticDecompression = System.Net.DecompressionMethods.All;
    })
    .AddTransforms<OpenAIChargebackTransformProvider>();


var app = builder.Build();
app.MapReverseProxy();
app.MapGet("/health", () => { return "Alive"; });
app.Run();








