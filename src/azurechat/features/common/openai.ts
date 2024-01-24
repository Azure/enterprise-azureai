import { OpenAI } from "openai";

export const OpenAIInstance = (apiKey : string) => {
  const openai = new OpenAI({
    apiKey: apiKey,
    defaultQuery: { "api-version": process.env.AZURE_OPENAI_API_VERSION },
    defaultHeaders: { "api-key": apiKey },
  });
  return openai;
};

export const OpenAIEmbeddingInstance = () => {
  const openai = new OpenAI({
    apiKey: process.env.OPENAI_API_KEY,
    //baseURL: `https://${process.env.AZURE_OPENAI_API_INSTANCE_NAME}.openai.azure.com/openai/deployments/${process.env.AZURE_OPENAI_API_EMBEDDINGS_DEPLOYMENT_NAME}`,
    baseURL: `${process.env.AZURE_OPENAI_API_INSTANCE_NAME}/openai/deployments/${process.env.AZURE_OPENAI_API_EMBEDDINGS_DEPLOYMENT_NAME}`,
    defaultQuery: { "api-version": process.env.AZURE_OPENAI_API_VERSION },
    defaultHeaders: { "api-key": process.env.OPENAI_API_KEY },
  });
  return openai;
};
