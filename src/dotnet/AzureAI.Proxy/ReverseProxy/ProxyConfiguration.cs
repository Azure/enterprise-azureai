using AzureAI.Proxy.Models;
using Yarp.ReverseProxy.Configuration;
using System.Text.Json;
using Yarp.ReverseProxy.LoadBalancing;
using Yarp.ReverseProxy.Forwarder;

namespace AzureAI.Proxy.ReverseProxy;

public class ProxyConfiguration
{

    private ProxyConfig _proxyConfig;

    public ProxyConfiguration(string configJson)
    {
        JsonSerializerOptions options = new();
        options.PropertyNameCaseInsensitive = true;

        _proxyConfig = JsonSerializer.Deserialize<ProxyConfig>(configJson, options);
    }

    public IReadOnlyList<RouteConfig> GetRoutes()
    {

        List<RouteConfig> routes = new();

        foreach (var route in _proxyConfig.Routes)
        {
            RouteConfig routeConfig = new()
            {
                RouteId = route.Name,
                ClusterId = route.Name,
                Match = new RouteMatch()
                {
                    Path = $"openai/deployments/{route.Name}/" + "{**catch-all}"
                }
            };

            routes.Add(routeConfig);

        }

        return routes.AsReadOnly();
    }

    public IReadOnlyList<ClusterConfig> GetClusters()
    {
        List<ClusterConfig> clusters = new();
        
        foreach (var route in _proxyConfig.Routes)
        {
            Dictionary<string, DestinationConfig> destinations = new();

            foreach (var destination in route.Endpoints)
            {
                Dictionary<string, string> metadata = new()
                {
                    { "url", destination.Address },
                    { "priority", destination.Priority.ToString() }
                };

                DestinationConfig destinationConfig = new()
                {
                    Address = destination.Address,
                    Metadata = metadata
                };

                destinations[destination.Address] = destinationConfig;

                
            }

            ClusterConfig clusterConfig = new()
            {
                ClusterId = route.Name,
                Destinations = destinations,
                HealthCheck = new HealthCheckConfig
                {
                    Passive = new PassiveHealthCheckConfig
                    {
                        Enabled = true,
                        Policy = ThrottlingHealthPolicy.ThrottlingPolicyName
                    }
                },
                //LoadBalancingPolicy = LoadBalancingPolicies.RoundRobin,
                HttpRequest = new ForwarderRequestConfig()
            };

            clusters.Add(clusterConfig);
        }
        
        return clusters.AsReadOnly();
    }
}
