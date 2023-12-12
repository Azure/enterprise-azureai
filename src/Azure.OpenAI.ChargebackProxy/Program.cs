using Azure.OpenAI.ChargebackProxy.ReverseProxy;
using Azure.OpenAI.ChargebackProxy.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddSingleton<IManagedIdentityService, ManagedIdentityService>();

var managedIdentityService = builder.Services.BuildServiceProvider().GetService<IManagedIdentityService>();


builder.Configuration.AddAzureAppConfiguration(options =>
    options.Connect(
        new Uri(builder.Configuration["AppConfigEndpoint"]),
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
    //.LoadFromConfig(builder.Configuration.GetSection("ReverseProxy"))
    .ConfigureHttpClient((sp, options) =>
    {
        //decompress the Response so we can read it
        options.AutomaticDecompression = System.Net.DecompressionMethods.All;
    })
    .AddTransforms<OpenAIChargebackTransformProvider>();


var app = builder.Build();
app.MapReverseProxy();
app.Run();








