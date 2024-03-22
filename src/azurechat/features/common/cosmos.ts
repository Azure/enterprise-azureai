import { Container, CosmosClient } from "@azure/cosmos";
import { GetSingleValue } from "./appconfig";
import { GetCredential } from "./managedIdentity";


const DB_NAME =  "chat";
const CONTAINER_NAME = "history";

const credential = GetCredential();


export const initDBContainer = async () => {

  const endpoint = await GetSingleValue("AzureChat:CosmosDbEndPoint");
  
  const client = new CosmosClient({
    endpoint,
    aadCredentials: credential
  });

  const database = (await client.database(DB_NAME).read()).database;
  const container = (await database.container(CONTAINER_NAME).read()).container;

  return container;
};

export class CosmosDBContainer {
  private static instance: CosmosDBContainer;
  private container: Promise<Container>;

  private constructor(endpoint: string) {
     
    const client = new CosmosClient({
      endpoint,
      aadCredentials: credential
    });

    this.container = new Promise((resolve, reject) => {
      client.database(DB_NAME).read()
        .then((databaseResponse) => {
          databaseResponse.database.container(CONTAINER_NAME).read()
            .then((containerResponse) => {
              resolve(containerResponse.container);
            });
        })
        .catch((err) => {
          reject(err);
        });
    });
  }

  public static async getInstance(): Promise<CosmosDBContainer> {
    if (!CosmosDBContainer.instance) {
      const endpoint = await GetSingleValue("AzureChat:CosmosDbEndPoint");
      
      CosmosDBContainer.instance = new CosmosDBContainer(endpoint);
    }

    return CosmosDBContainer.instance;
  }

  public async getContainer(): Promise<Container> {
    return await this.container;
  }
}
