using Azure.Core;
using Azure.Identity;

namespace Azure.OpenAI.ChargebackProxy.Services
{
    public class ManagedIdentityService : IManagedIdentityService
    {
        private TokenCredential _credential;
        private readonly IConfiguration _config;
        private readonly IWebHostEnvironment _environment;

        public ManagedIdentityService(IConfiguration config, IWebHostEnvironment environment)
        {
            _config = config;
            _environment = environment;
        }

        public TokenCredential GetTokenCredential()
        {
            _credential = new DefaultAzureCredential(GetDefaultAzureCredentialOptions());
            return _credential;
        }

        private DefaultAzureCredentialOptions GetDefaultAzureCredentialOptions()
        {

            DefaultAzureCredentialOptions options = new DefaultAzureCredentialOptions();

            if (_environment.IsDevelopment()) {
                options.ExcludeManagedIdentityCredential = true;
                options.ExcludeWorkloadIdentityCredential = true;
            }
            else
            {
                options.ExcludeVisualStudioCredential = true;
                options.ExcludeVisualStudioCredential = true;
                options.ExcludeAzureCliCredential = true;
                options.ExcludeAzureDeveloperCliCredential = true;
                options.ExcludeAzurePowerShellCredential = true;
                options.ExcludeInteractiveBrowserCredential = true;
            }

            if (_config["EntraId:TenantId"] is not null)
            {
                options.TenantId = _config["EntraId:TenantId"];
            }

            if (_config["CLIENT_ID"] is not null)
            {
                options.ManagedIdentityClientId = _config["CLIENT_ID"];
            }

            return options;
        }

      
    }

    
}
