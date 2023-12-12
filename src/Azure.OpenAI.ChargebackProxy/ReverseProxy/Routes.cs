using Microsoft.Extensions.Azure;
using Yarp.ReverseProxy.Configuration;

namespace Azure.OpenAI.ChargebackProxy.ReverseProxy
{
    public class Routes
    {
        public static IReadOnlyList<RouteConfig> GetRoutes()
        {
            RouteConfig routeConfig = new()
            {
                RouteId = "AzureOpenAI",
                ClusterId = "AzureOpenAI",
                Match = new RouteMatch()
                {
                    Path = "{**catch-all}"
                }
            };

            List<RouteConfig> routes = new List<RouteConfig> { routeConfig };
                      

            return routes.AsReadOnly();
        }
    }
}
