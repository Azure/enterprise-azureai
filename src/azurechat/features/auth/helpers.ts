import { createHash } from "crypto";
import { getServerSession } from "next-auth";
import { options } from "./auth-api";
import { GetKey } from "../common/keyvault";
import { GetSingleValue } from "../common/appconfig";
import { resolve } from "path";

export const userSession = async (): Promise<UserModel | null> => {
  const session = await getServerSession(options);
  if (session && session.user) {
    return session.user as UserModel;
  }

  return null;
};

export const userHashedId = async (): Promise<string> => {
  const user = await userSession();
  if (user) {
    return hashValue(user.email);
  }

  throw new Error("User not found");
};

export type UserModel = {
  name: string;
  image: string;
  email: string;
};

export const hashValue = (value: string): string => {
  const hash = createHash("sha256");
  hash.update(value);
  return hash.digest("hex");
};

export class EntraIdKeys  {
  clientId: string;
  clientSecret: string;
  tenantId: string;

  constructor() {
      this.clientId = "";
      this.clientSecret = "";
      this.tenantId = "";
  }
}

export async function initAad(keys: EntraIdKeys) {
  
  keys.clientId = await GetKey("AzureChatClientId");
  keys.clientSecret = await GetKey("AzureChatClientSecret");
  keys.tenantId = await GetSingleValue("EntraId:TenantId");

  return keys;
}