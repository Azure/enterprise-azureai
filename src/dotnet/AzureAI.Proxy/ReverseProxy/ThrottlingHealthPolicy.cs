using Yarp.ReverseProxy.Health;
using Yarp.ReverseProxy.Model;

namespace AzureAI.Proxy.ReverseProxy;

public class ThrottlingHealthPolicy : IPassiveHealthCheckPolicy
{
    public static string ThrottlingPolicyName = "ThrottlingPolicy";
    private readonly IDestinationHealthUpdater _healthUpdater;

    public ThrottlingHealthPolicy(IDestinationHealthUpdater healthUpdater)
    {
        _healthUpdater = healthUpdater;
    }

    public string Name => ThrottlingPolicyName;

    public void RequestProxied(HttpContext context, ClusterState cluster, DestinationState destination)
    {
        var headers = context.Response.Headers;

        if (context.Response.StatusCode is 429 or >= 500)
        {
            var retryAfterSeconds = 10;

            if (headers.TryGetValue("Retry-After", out var retryAfterHeader) && retryAfterHeader.Count > 0 && int.TryParse(retryAfterHeader[0], out var retryAfter))
            {
                retryAfterSeconds = retryAfter;
            }
            else
            if (headers.TryGetValue("x-ratelimit-reset-requests", out var ratelimiResetRequests) && ratelimiResetRequests.Count > 0 && int.TryParse(ratelimiResetRequests[0], out var ratelimiResetRequest))
            {
                retryAfterSeconds = ratelimiResetRequest;
            }
            else
            if (headers.TryGetValue("x-ratelimit-reset-tokens", out var ratelimitResetTokens) && ratelimitResetTokens.Count > 0 && int.TryParse(ratelimitResetTokens[0], out var ratelimitResetToken))
            {
                retryAfterSeconds = ratelimitResetToken;
            }

            _healthUpdater.SetPassive(cluster, destination, DestinationHealth.Unhealthy, TimeSpan.FromSeconds(retryAfterSeconds));
        }
    }
}