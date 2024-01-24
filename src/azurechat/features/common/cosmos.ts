import { Container, CosmosClient } from "@azure/cosmos";
import { GetSingleValue } from "./appconfig";
import { DefaultAzureCredential } from "@azure/identity";


const DB_NAME =  "chat";
const CONTAINER_NAME = "history";

const credential = new DefaultAzureCredential();


export const initDBContainer = async () => {

  const endpoint = await GetSingleValue("AzureChat:CosmosDbEndPoint");
  console.log("Cosmos endpoint (init)", endpoint);
  const client = new CosmosClient({
    endpoint,
    aadCredentials: credential
  });

  const databaseResponse = await client.databases.createIfNotExists({
    id: DB_NAME,
  });

  const containerResponse =
    await databaseResponse.database.containers.createIfNotExists({
      id: CONTAINER_NAME,
      partitionKey: {
        paths: ["/userId"],
      },
    });

  return containerResponse.container;
};

export class CosmosDBContainer {
  private static instance: CosmosDBContainer;
  private container: Promise<Container>;

  private constructor(endpoint: string) {
     console.log("Cosmos endpoint (constructor)", endpoint);
    const client = new CosmosClient({
      endpoint,
      aadCredentials: credential
    });

   
    this.container = new Promise((resolve, reject) => {
      client.databases
        .createIfNotExists({
          id: DB_NAME,
        })
        .then((databaseResponse) => {
          databaseResponse.database.containers
            .createIfNotExists({
              id: CONTAINER_NAME,
              partitionKey: {
                paths: ["/userId"],
              },
            })
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
      console.log("Cosmos endpoint (instance)", endpoint);
      CosmosDBContainer.instance = new CosmosDBContainer(endpoint);
    }

    return CosmosDBContainer.instance;
  }

  public async getContainer(): Promise<Container> {
    return await this.container;
  }
}
