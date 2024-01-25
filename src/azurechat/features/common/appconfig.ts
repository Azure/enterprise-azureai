import { AppConfigurationClient } from "@azure/app-configuration"
import { DepartmentConfig, DeploymentConfig } from "../chat/chat-services/models";
import { GetCredential } from "./managedIdentity";

const appConfig = (): AppConfigurationClient => {
    const credential = GetCredential();
    const configurationEndpoint = `${process.env.APPCONFIG_ENDPOINT}`

    const client = new AppConfigurationClient(
        configurationEndpoint,
        credential
    );
    return client;
}

const appConfigStore = appConfig();

export async function GetDeployments() {
  const deploymentsJson = await appConfigStore.getConfigurationSetting({
    key: "AzureChat:Deployments"
  });

  const deployments = JSON.parse(deploymentsJson.value as string) as DeploymentConfig[];
  return deployments;
}

export async function GetDepartments() {
  const departmentsJson = await appConfigStore.getConfigurationSetting({
    key: "AzureChat:Departments"
  });

  const departments = JSON.parse(departmentsJson.value as string) as DepartmentConfig[];
  return departments;
}

export async function GetSingleValue(key: string) {
  const singleValue = await appConfigStore.getConfigurationSetting({
    key: key
  });
 
  return singleValue.value as string;
}

