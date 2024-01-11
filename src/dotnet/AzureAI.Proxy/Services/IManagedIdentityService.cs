using Azure.Core;

namespace AzureAI.Proxy.Services
{
    public interface IManagedIdentityService
    {
        TokenCredential GetTokenCredential();
    }
}
