import { SecretClient } from "@azure/keyvault-secrets";
import { GetSingleValue } from "./appconfig";
import { GetCredential } from "./managedIdentity";



const keyVault = (url: string): SecretClient => {
    const credential = GetCredential();
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

export async function GetKey(keyName: string) {
    const url = await GetSingleValue("AzureChat:Keyvault");   
    const client = keyVault(url);
    const key = await client.getSecret(keyName);
    return key.value as string;
}