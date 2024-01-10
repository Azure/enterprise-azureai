using Yarp.ReverseProxy.Configuration;

namespace AzureAI.Proxy.ReverseProxy
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
                    Path = "openai/{**catch-all}"
                }
            };

            List<RouteConfig> routes = new List<RouteConfig> { routeConfig };
                      

            return routes.AsReadOnly();
        }
    }
}
