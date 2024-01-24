import { SecretClient } from "@azure/keyvault-secrets";
import { DefaultAzureCredential } from "@azure/identity";
import { GetSingleValue } from "./appconfig";



const keyVault = (url: string): SecretClient => {
    const credential = new DefaultAzureCredential();
    const client = new SecretClient(
        url,
        credential
    );
    return client;
}

export async function GetAPIKey(department: string) {
    const url = await GetSingleValue("AzureChat:Keyvault");   
    const client = keyVault(url);
    const apiKey = await client.getSecret(department);
    return apiKey.value;
}