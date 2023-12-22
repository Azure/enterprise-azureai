# Setting up Azure OpenAI as a central capability with Azure API Management

Unleash the power of Azure OpenAI to your application developers in a secure & manageable way with Azure API Management and Azure Developer CLI(`azd`).

[![Open in GitHub Codespaces](https://img.shields.io/static/v1?style=for-the-badge&label=GitHub+Codespaces&message=Open&color=lightgrey&logo=github)](https://codespaces.new/pascalvanderheiden/ais-apim-openai)
[![Open in Dev Container](https://img.shields.io/static/v1?style=for-the-badge&label=Dev+Container&message=Open&color=blue&logo=visualstudiocode)](https://vscode.dev/redirect?url=vscode://ms-vscode-remote.remote-containers/cloneInVolume?url=https://github.com/pascalvanderheiden/ais-apim-openai)

Available as template on:
[![Awesome Badge](https://awesome.re/badge-flat2.svg)](https://aka.ms/awesome-azd)
`azd`

## Build Status

| GitHub Action | Status |
| ----------- | ----------- |
| `azd` Deploy | [![Deploy](https://github.com/pascalvanderheiden/ais-apim-openai/actions/workflows/azure-dev.yml/badge.svg?branch=main)](https://github.com/pascalvanderheiden/ais-apim-openai/actions/workflows/azure-dev.yml) |

## About

This repository demonstrates how to setup Azure OpenAI as a central capability within your organization with Azure API Management and Azure Container Apps. Azure OpenAI is a service that provides AI models that are trained on a large amount of data. You can use these models to generate text, images, and more. Azure API Management is a fully managed service that enables customers to publish, secure, transform, maintain, and monitor APIs. It is a great way to expose your APIs to the outside world in a secure and manageable way. In addition to that, we've added Azure Container Apps, which allows you to run containerized applications in Azure without having to manage any infrastructure. The containerized application in this repository is a .NET 8.0 chargeback proxy application, which allows you to chargeback the costs of the Azure OpenAI service to the application that is using it. This is a great way to control the costs of the Azure OpenAI service and offer it as a centralized capability within your organization. The chargeback proxy also supports load balancing across multiple Azure OpenAI instances, which allows you to scale the Azure OpenAI service horizontally, or enable multiple deployment models which are sometimes only available in specific regions. The chargeback report is presented in the Azure Dashboard, which is a great way to visualize the costs of the Azure OpenAI service.

I've used the Azure Developer CLI Bicep Starter template to create this repository. With `azd` you can create a new repository with a fully functional CI/CD pipeline in minutes. You can find more information about `azd` [here](https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/).

One of the key points of `azd` templates is that we can implement best practices together with our solution when it comes to security, network isolation, monitoring, etc. Users are free to define their own best practices for their dev teams & organization, so all deployments are followed by the same standards.

The best practices we've followed for this architecture are: [Azure Integration Service Landingzone Accelerator](https://github.com/Azure/Integration-Services-Landing-Zone-Accelerator/tree/main) and for Azure OpenAI we've used the blog post [Azure OpenAI Landing Zone reference architecture](https://techcommunity.microsoft.com/t5/azure-architecture-blog/azure-openai-landing-zone-reference-architecture/ba-p/3882102). For the chargeback proxy we've used the setup from the [Azure Container Apps Landingzone Accelerator](https://github.com/Azure/aca-landing-zone-accelerator).

When it comes to security, there are recommendations mentioned for securing your Azure API Management instance in the Azure Integration Service Landingzone Accelerator. For example, with the use of Front Door or Application Gateway, proving Layer 7 protection and WAF capabilities, and by implementing OAuth authentication on the API Management instance. How to implement OAuth authentication on the API Management instance is described in another repository: [OAuth flow with Azure AD and Azure API Management.](https://github.com/pascalvanderheiden/ais-apim-oauth-flow). Because it really depends on the use case, we didn't implement Front Door or Application Gateway in this repository. But you can easily add it to the Bicep files if you want to, see [this](https://github.com/pascalvanderheiden/ais-sync-pattern-la-std-vnet) repository for as an example.

I'm also using [Azure Monitor Private Link Scope](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/private-link-security#configure-access-to-your-resources). This allows me to define the boundaries of my monitoring network, and only allow traffic from within that network to my Log Analytics workspace. This is a great way to secure your monitoring network.

The following assets have been provided:

- Infrastructure-as-code (IaC) Bicep files under the `infra` folder that demonstrate how to provision resources and setup resource tagging for azd.
- A [dev container](https://containers.dev) configuration file under the `.devcontainer` directory that installs infrastructure tooling by default. This can be readily used to create cloud-hosted developer environments such as [GitHub Codespaces](https://aka.ms/codespaces).
- Continuous deployment workflows for CI providers such as GitHub Actions under the `.github` directory, and Azure Pipelines under the `.azdo` directory that work for most use-cases.
- The .NET 8.0 chargeback proxy application under the `src` folder.

## Credits

Without the help of [Remko Brosky](https://github.com/azureholic) this amazing repository wouldn't have been possible. He helped me with the Bicep files and the chargeback proxy application. So a big shoutout to him!

## Architecture

![ais-apim-openai](docs/images/arch.png)

## Prerequisites

- [Azure Developer CLI](https://docs.microsoft.com/en-us/azure/developer/azure-developer-cli/)
- [.NET 8.0 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- [Docker Desktop](https://www.docker.com/products/docker-desktop)

## Next Steps

### Step 1: Initialize a new `azd` environment

```shell
azd init
```

It will prompt you to provide a name that will later be used in the name of the deployed resources.

### Step 2: Set some environment variables

```shell
azd env set USE_REDIS_CACHE_APIM '<true-or-false>'
azd env set SECONDARY_OPENAI_LOCATION '<your-secondary-openai-location>'
```

There is one environment variable we set automatically in the `azd` template, and that is your ip address. We use this to allow traffic from your local machine to the Azure Container Registry to deploy the containerized application.

### Step 3: Provision and deploy all the resources

```shell
azd up
```

It will prompt you to login, pick a subscription, and provide a location (like "eastus"). Then it will provision the resources in your account and deploy the latest code.

For more details on the deployed services, see [additional details](#additional-details) below.

> Note. Because Azure OpenAI isn't available yet in all regions, you might get an error when you deploy the resources. You can find more information about the availability of Azure OpenAI [here](https://docs.microsoft.com/en-us/azure/openai/overview/regions).
> Note. It will take about 25 minutes to deploy Azure Redis Cache, that's why it's optional.
> Note. Sometimes the dns zones for the private endpoints aren't created correctly / in time. If you get an error when you deploy the resources, you can try to deploy the resources again.

## CI/CD pipeline

This project includes a Github workflow and a Azure DevOps Pipeline for deploying the resources to Azure on every push to main. That workflow requires several Azure-related authentication secrets to be stored as Github action secrets. To set that up, run:

```shell
azd pipeline config
```

## Monitoring

The deployed resources include a Log Analytics workspace with an Application Insights based dashboard to measure metrics like server response time and failed requests. We also included some custom visuals in the dashboard to visualize the token usage per consumer of the Azure OpenAI service.

![ais-apim-openai](docs/images/dashboard.png)

To open that dashboard, run this command once you've deployed:

```shell
azd monitor --overview
```

## Remove the APIM Soft-delete

If you deleted the deployment via the Azure Portal, and you want to run this deployment again, you might run into the issue that the APIM name is still reserved because of the soft-delete feature. You can remove the soft-delete by using this az cli command:

```bash
location = "<your-location>"
apimName = "<your-apim-name>"
subscriptionId = "<your-subscription-id>"
az account set --subscription $subscriptionId
az apim deletedservice purge --location $location --service-name $apimName
```

## Testing

I've included a [tests.http](tests.http) file with relevant tests you can perform, to check if your deployment is successful. You need the 2 subcription keys for Marketing and Finance, created in API Management in order to test the API. You can find more information about how to create subscription keys [here](https://docs.microsoft.com/en-us/azure/api-management/api-management-howto-create-subscriptions#add-a-subscription-key-to-a-user).

## Additional Details

The following section examines different concepts that help tie in application and infrastructure.

### Azure API Management

[Azure API Management](https://azure.microsoft.com/en-us/services/api-management/) is a fully managed service that enables customers to publish, secure, transform, maintain, and monitor APIs. It is a great way to expose your APIs to the outside world in a secure and manageable way.

### Azure OpenAI

[Azure OpenAI](https://azure.microsoft.com/en-us/services/openai/) is a service that provides AI models that are trained on a large amount of data. You can use these models to generate text, images, and more.

### Managed identities

[Managed identities](https://learn.microsoft.com/en-us/azure/active-directory/managed-identities-azure-resources/overview) allows you to secure communication between services. This is done without having the need for you to manage any credentials.

### Virtual Network

[Azure Virtual Network](https://azure.microsoft.com/en-us/services/virtual-network/) allows you to create a private network in Azure. You can use this to secure communication between services.

### Azure Private DNS Zone

[Azure Private DNS Zone](https://docs.microsoft.com/en-us/azure/dns/private-dns-overview) allows you to create a private DNS zone in Azure. You can use this to resolve hostnames in your private network.

### Application Insights

[Application Insights](https://azure.microsoft.com/en-us/services/monitor/) allows you to monitor your application. You can use this to monitor the performance of your application.

### Log Analytics

[Log Analytics](https://azure.microsoft.com/en-us/services/monitor/) allows you to collect and analyze telemetry data from your application. You can use this to monitor the performance of your application.

### Azure Monitor Private Link Scope

[Azure Monitor Private Link Scope](https://learn.microsoft.com/en-us/azure/azure-monitor/logs/private-link-security#configure-access-to-your-resources) allows you to define the boundaries of your monitoring network, and only allow traffic from within that network to your Log Analytics workspace. This is a great way to secure your monitoring network.

### Private Endpoint

[Azure Private Endpoint](https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-overview) allows you to connect privately to a service powered by Azure Private Link. Private Endpoint uses a private IP address from your VNet, effectively bringing the service into your VNet.

### Azure Container Apps

[Azure Container Apps](https://azure.microsoft.com/en-us/services/container-app/) allows you to run containerized applications in Azure without having to manage any infrastructure.

### Azure Container Registry

[Azure Container Registry](https://azure.microsoft.com/en-us/services/container-registry/) allows you to store and manage container images and artifacts in a private registry for all types of container deployments.

### Azure Redis Cache

[Azure Redis Cache](https://azure.microsoft.com/en-us/services/cache/) allows you to use a secure open source Redis cache.

### Azure Container Environment

[Azure Container Environment](https://docs.microsoft.com/en-us/azure/container-instances/container-instances-container-app) allows you to run containerized applications in Azure without having to manage any infrastructure.

