using Azure.Core;
using Azure.Identity;

namespace Azure.OpenAI.ChargebackProxy.Services
{
    public class ManagedIdentityService : IManagedIdentityService
    {
        private TokenCredential _credential;
        public TokenCredential GetTokenCredential(DefaultAzureCredentialOptions defaultAzureCredentialOptions )
        {
            _credential = new DefaultAzureCredential(defaultAzureCredentialOptions);
            return _credential;
        }
    }
}
