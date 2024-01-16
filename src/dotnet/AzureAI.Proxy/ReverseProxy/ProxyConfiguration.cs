using AzureAI.Proxy.Models;
using Yarp.ReverseProxy.Configuration;
using System.Text.Json;
using Yarp.ReverseProxy.LoadBalancing;

namespace AzureAI.Proxy.ReverseProxy;

public class ProxyConfiguration
{

    private ProxyConfig _proxyConfig;

    public ProxyConfiguration(string configJson)
    {
        _proxyConfig = JsonSerializer.Deserialize<ProxyConfig>(configJson);
    }

    public IReadOnlyList<RouteConfig> GetRoutes()
    {

        List<RouteConfig> routes = new();

        foreach (var route in _proxyConfig.routes)
        {
            RouteConfig routeConfig = new()
            {
                RouteId = route.name,
                ClusterId = route.name,
                Match = new RouteMatch()
                {
                    Path = $"openai/deployments/{route.name}/" + "{**catch-all}"
                }
            };

            routes.Add(routeConfig);

        }

        return routes.AsReadOnly();
    }

    public IReadOnlyList<ClusterConfig> GetClusters()
    {
        List<ClusterConfig> clusters = new();

        Dictionary<string, DestinationConfig> destinations = new();

        foreach (var route in _proxyConfig.routes)
        {
            foreach (var destination in route.endpoints)
            {
                Dictionary<string, string> metadata = new()
                {
                    { "url", destination.address },
                    { "priority", destination.priority.ToString() }
                };

                DestinationConfig destinationConfig = new()
                {
                    Address = destination.address,
                    Metadata = metadata
                };

                destinations[destination.address] = destinationConfig;

                
            }

            ClusterConfig clusterConfig = new()
            {
                ClusterId = route.name,
                Destinations = destinations,
                LoadBalancingPolicy = LoadBalancingPolicies.RoundRobin
            };

            clusters.Add(clusterConfig);
        }
        
        return clusters.AsReadOnly();
    }
}
