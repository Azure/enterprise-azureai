using Azure.Core;
using Azure.Identity;

namespace Azure.OpenAI.ChargebackProxy.Services
{
    public interface IManagedIdentityService
    {
        TokenCredential GetTokenCredential();
    }
}
