using System.Text.Json;
using Yarp.ReverseProxy.Configuration;
using Yarp.ReverseProxy.LoadBalancing;

namespace AzureAI.Proxy.ReverseProxy
{
    public class Clusters
    {
        public static  IReadOnlyList<ClusterConfig> GetClusterConfig(IConfiguration config)
        {

            var destinations = config["AzureOpenAI:Endpoints"];
            var urls = JsonSerializer.Deserialize<List<string>>(destinations);


            Dictionary<string, DestinationConfig> destinationDictonary = new Dictionary<string, DestinationConfig>();

            foreach (string destination in urls)
            {
                DestinationConfig destinationConfig = new()
                {
                    Address = destination
                };

                destinationDictonary[destination] = destinationConfig;
            }




            ClusterConfig clusterConfig = new()
            {
                ClusterId = "AzureOpenAI",
                Destinations = destinationDictonary,
                LoadBalancingPolicy = LoadBalancingPolicies.RoundRobin
            };


            List<ClusterConfig> clusters = new List<ClusterConfig> { clusterConfig };


            return clusters.AsReadOnly();
            

        }
    }
}
