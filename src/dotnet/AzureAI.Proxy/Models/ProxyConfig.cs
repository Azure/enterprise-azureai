namespace AzureAI.Proxy.Models;


public class ProxyConfig
{
    public List<Route> routes { get; set; }
}

public class Route
{
    public string name { get; set; }
    public List<Endpoint> endpoints { get; set; }
}

public class Endpoint
{
    public string address { get; set; }
    public int priority { get; set; }
}
