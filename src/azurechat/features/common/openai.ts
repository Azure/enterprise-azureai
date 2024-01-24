import { OpenAI } from "openai";

export const OpenAIInstance = (apiKey : string, apiVersion: string) => {
  const openai = new OpenAI({
    apiKey: apiKey,
    defaultQuery: { "api-version": apiVersion },
    defaultHeaders: { "api-key": apiKey },
  });
  return openai;
};

export const OpenAIEmbeddingInstance = (apiKey: string, apiVersion: string) => {
  const openai = new OpenAI({
    apiKey: apiKey,
    defaultQuery: { "api-version": apiVersion },
    defaultHeaders: { "api-key": apiKey },
  });
  return openai;
};
