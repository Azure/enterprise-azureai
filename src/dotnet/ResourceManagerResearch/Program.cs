using Azure.Identity;
using Azure.ResourceManager;
using Azure.ResourceManager.CognitiveServices;
using Azure.ResourceManager.Resources;
using Microsoft.Extensions.Configuration;
using Yarp.ReverseProxy.Configuration;
using Yarp.ReverseProxy.LoadBalancing;


var config = new ConfigurationBuilder().AddUserSecrets<Program>().Build();

string defaultSubscriptionId = config["AzureSubscription"];
ArmClient azure = new ArmClient(new DefaultAzureCredential(MyOptions()), defaultSubscriptionId);

ResourceGroupResource rg = azure.GetDefaultSubscription().GetResourceGroup("rg-ai");

CognitiveServicesAccountCollection cognitiveServicesAccounts = rg.GetCognitiveServicesAccounts();


//create cluster per unique deploymentname
Dictionary<string, List<string>> tempClusters = new();



foreach (var cognitiveServicesAccount in cognitiveServicesAccounts)
{
    if (cognitiveServicesAccount.Data.Kind == "OpenAI")
    {
        CognitiveServicesAccountDeploymentCollection deployments = cognitiveServicesAccount.GetCognitiveServicesAccountDeployments();
        foreach (var deployment in deployments)
        {
            if (!tempClusters.ContainsKey(deployment.Data.Name))
            {
                tempClusters.Add(deployment.Data.Name, new List<string>());
                tempClusters[deployment.Data.Name].Add(cognitiveServicesAccount.Data.Properties.Endpoint);
            }
            else
            {
                tempClusters[deployment.Data.Name].Add(cognitiveServicesAccount.Data.Properties.Endpoint);
            }
        }
    }
}


//print all the clusters and their endpoints
foreach (var entry in tempClusters)
{
   Console.WriteLine($"{entry.Key}");
    foreach (var url in entry.Value)
    {
         Console.WriteLine($"    {url}");
    }
}





static DefaultAzureCredentialOptions MyOptions()
{
    var myOptions = new DefaultAzureCredentialOptions();

    //I prefer to use the AzureCLI credential only
    myOptions.ExcludeAzureCliCredential = false;

    //Exclude all the other options
    myOptions.ExcludeAzurePowerShellCredential = true;
    myOptions.ExcludeEnvironmentCredential = true;
    myOptions.ExcludeInteractiveBrowserCredential = true;
    myOptions.ExcludeManagedIdentityCredential = true;
    myOptions.ExcludeSharedTokenCacheCredential = true;
    myOptions.ExcludeVisualStudioCodeCredential = true;
    myOptions.ExcludeVisualStudioCredential = true;

    return myOptions;
}
