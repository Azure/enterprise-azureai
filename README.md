# ais-apim-devops

## Build Status

| GitHub Action | Status |
| ----------- | ----------- |
| Build | [![Build](https://github.com/pascalvanderheiden/ais-apim-devops/actions/workflows/build.yml/badge.svg?branch=main)](https://github.com/pascalvanderheiden/ais-apim-devops/actions/workflows/build.yml) |
| Release | [![Release](https://github.com/pascalvanderheiden/ais-apim-devops/actions/workflows/release.yml/badge.svg)](https://github.com/pascalvanderheiden/ais-apim-devops/actions/workflows/release.yml) |

## About

This a repository about how you can setup [Azure API Management](https://docs.microsoft.com/en-us/azure/api-management/overview) service via a centrally managed team, which enforced organizational policies, but provides a self-service experience for developers to manage their own APIs. This is question I get every often, and I wanted to create a reference architecture for this.

Policies are used to modify, enforced on different levels and secure your APIs in API Management. The API Management Product Team already created a very useful set of [snippets](https://github.com/Azure/api-management-policy-snippets), but I wanted to make it easy to use and deploy them. I've added the VSCode snippets file from the above repository to this VSCode project. This makes it a lot easier to create your policies from VSCode. Follow [this instruction](https://code.visualstudio.com/docs/editor/userdefinedsnippets#_create-your-own-snippets) to create your own snippets or use this one with other projects. 

For deployment I choose to do it all in Bicep templates. I got most of my examples from [here](https://github.com/Azure/bicep/tree/main/docs/examples).

For the teams to have their own environment of API Management, we'll be using the Preview Feature in API Management, Workspaces.

Hope you find this useful!

## Architecture

![ais-apim-devops](docs/images/arch.png)

## Prerequisites

* Install [Visual Studio Code](https://code.visualstudio.com/download)
* Install [REST Client](https://marketplace.visualstudio.com/items?itemName=humao.rest-client) Extension for Visual Studio Code.
* Install [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)

## Deploy Manually

* Git Clone the repository

```ps1
git clone https://github.com/pascalvanderheiden/ais-apim-snippets.git
```

* Deploy it all by one script

I've included all the steps in 1 Powershell script. This will create all the needed resources. Keep in mind that this will take a while to deploy.

I've used these variables:

```ps1
$subscriptionId = "<subscription_id>"
$namePrefix = "<project_prefix>"

# For removing soft-delete
$apimName = "<apim_name>"
```

```ps1
.\deploy\manual-deploy.ps1 -subscriptionId $subscriptionId -namePrefix $namePrefix
```

* Remove the APIM Soft-delete

If you deleted the deployment via the Azure Portal, and you want to run this deployment again, you might run into the issue that the APIM name is still reserved because of the soft-delete feature. You can remove the soft-delete by using this script:

```ps1
.\deploy\del-soft-delete-apim.ps1 -subscriptionId $subscriptionId -apimName $apimName
```

* Testing

I've included a tests.http file with relevant Test you can perform, to check if your deployment is successful.

## Deploy with Azure DevOps

tbd

## Setup Azure DevOps for Teams

## Deploy with Github Actions

* Fork this repository

* Generate a Service Principal

```ps1
az ad sp create-for-rbac -n <name_sp> --role Contributor --sdk-auth --scopes /subscriptions/<subscription_id>
```

Copy the json output of this command.

* Update GitHub Secrets for customizing your deployment

In the repository go to 'Settings', on the left 'Secrets', 'Actions'.
And pass the json output in the command used above into the secret 'AZURE_CREDENTIALS'.

The following secrets need to be created:

* AZURE_CREDENTIALS
* AZURE_SUBSCRIPTION_ID
* LOCATION
* PREFIX

### Commit

Commit the changes, and this will trigger the CI Build Pipeline.