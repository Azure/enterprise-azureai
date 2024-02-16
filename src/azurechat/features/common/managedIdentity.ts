import { DefaultAzureCredential } from "@azure/identity"

export function GetCredential() {
    return new DefaultAzureCredential();
}