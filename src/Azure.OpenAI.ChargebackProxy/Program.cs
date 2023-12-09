using Azure.OpenAI.ChargebackProxy.Services;
using Azure.OpenAI.ChargebackProxy.Transforms;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

var builder = WebApplication.CreateBuilder(args);

var config = builder.Configuration;
ILogger logger = builder.Services.BuildServiceProvider().GetRequiredService<ILogger<Program>>();


builder.Services.AddSingleton<IManagedIdentityService, ManagedIdentityService>();
builder.Services.AddSingleton<ILogIngestionService, LogIngestionService>((ctx) =>
{
    var managedIdentityService = ctx.GetService<IManagedIdentityService>();
    return new LogIngestionService(managedIdentityService, config, logger);
});

builder.Services.AddReverseProxy()
    .LoadFromConfig(builder.Configuration.GetSection("ReverseProxy"))
    .ConfigureHttpClient((sp, options) =>
    {
        //decompress the Response so we can read it
        options.AutomaticDecompression = System.Net.DecompressionMethods.All;
    })
    .AddTransforms<OpenAIChargebackTransformProvider>();


var app = builder.Build();
app.MapReverseProxy();
app.Run();








