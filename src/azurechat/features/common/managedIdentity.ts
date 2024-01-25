import { DefaultAzureCredential } from "@azure/identity"

export function GetCredential() {
  
  let options = {
    managedIdentityClientId: process.env.CLIENT_ID == null ? "" : process.env.CLIENT_ID,
    tenantId: process.env.TENANT_ID == null ? "" : process.env.TENANT_ID
    
  }
  return new DefaultAzureCredential(options);
}