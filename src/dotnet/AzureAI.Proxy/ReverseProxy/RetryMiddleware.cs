using Yarp.ReverseProxy.Model;

namespace AzureAI.Proxy.ReverseProxy;

public class RetryMiddleware
{
    private readonly RequestDelegate _next;
     private readonly ILogger _logger;

    public RetryMiddleware(RequestDelegate next, ILoggerFactory loggerFactory)
    {
        _next = next;
        _logger = loggerFactory.CreateLogger<RetryMiddleware>();
    }

    /// <summary>
    /// The code in this method is based on comments from https://github.com/microsoft/reverse-proxy/issues/56
    /// When YARP natively supports retries, this will probably be greatly simplified.
    /// </summary>
    public async Task InvokeAsync(HttpContext context)
    {
        context.Request.EnableBuffering();

        var shouldRetry = true;
        var retryCount = 0;

        while (shouldRetry)
        {
            var reverseProxyFeature = context.GetReverseProxyFeature();
            var destination = PickOneDestination(reverseProxyFeature);

            reverseProxyFeature.AvailableDestinations = new List<DestinationState>(destination);

            if (retryCount > 0)
            {
                //If this is a retry, we must reset the request body to initial position and clear the current response
                context.Request.Body.Position = 0;
                reverseProxyFeature.ProxiedDestination = null;
                context.Response.Clear();
            }

            await _next(context);

            var statusCode = context.Response.StatusCode;
            var atLeastOneBackendHealthy = GetNumberHealthyEndpoints(context) > 0;
            retryCount++;

            shouldRetry = (statusCode is 429 or >= 500) && atLeastOneBackendHealthy;
        }
    }

    private static int GetNumberHealthyEndpoints(HttpContext context)
    {
        return context.GetReverseProxyFeature().AllDestinations.Count(m => m.Health.Passive is DestinationHealth.Healthy or DestinationHealth.Unknown);
    }


    /// <summary>
    /// The native YARP ILoadBalancingPolicy interface does not play well with HTTP retries, that's why we're adding this custom load-balancing code.
    /// This needs to be reevaluated to a ILoadBalancingPolicy implementation when YARP supports natively HTTP retries.
    /// </summary>
    private DestinationState PickOneDestination(IReverseProxyFeature reverseProxyFeature)
    {
        List<DestinationState> allDestinations = new List<DestinationState>(reverseProxyFeature.AllDestinations);
        allDestinations.Sort(delegate (DestinationState a, DestinationState b)
        {
            int prioA = int.Parse(a.Model.Config.Metadata["priority"]);
            int prioB = int.Parse(b.Model.Config.Metadata["priority"]);
            return prioA.CompareTo(prioB);
        });

        var selectedPriority = int.MaxValue;
        var availableBackends = new List<int>();

        for (var i = 0; i < allDestinations.Count; i++)
        {
            var destination = allDestinations[i];

            if (destination.Health.Passive != DestinationHealth.Unhealthy)
            {
                var destinationPriority = int.Parse(destination.Model.Config.Metadata["priority"]);

                if (destinationPriority < selectedPriority)
                {
                    selectedPriority = destinationPriority;
                    availableBackends.Clear();
                    availableBackends.Add(i);
                }
                else if (destinationPriority == selectedPriority)
                {
                    availableBackends.Add(i);
                }
            }
        }

        int backendIndex;

        if (availableBackends.Count == 1)
        {
            //Returns the only available backend if we have only one available
            backendIndex = availableBackends[0];
        }
        else
        if (availableBackends.Count > 0)
        {
            //Returns a random backend from the list if we have more than one available with the same priority
            backendIndex = availableBackends[Random.Shared.Next(0, availableBackends.Count)];
        }
        else
        {
            //Returns a random  backend if all backends are unhealthy
            _logger.LogWarning($"All backends are unhealthy. Picking a random backend...");
            backendIndex = Random.Shared.Next(0, allDestinations.Count);
        }

        var pickedDestination = allDestinations[backendIndex];
        _logger.LogInformation($"Picked backend: {pickedDestination.Model.Config.Address}");

        return pickedDestination;
    }
}
