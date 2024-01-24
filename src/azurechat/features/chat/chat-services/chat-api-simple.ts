import { userHashedId } from "@/features/auth/helpers";
import { OpenAIInstance } from "@/features/common/openai";
import { AI_NAME } from "@/features/theme/customise";
import { OpenAIStream, StreamingTextResponse } from "ai";
import { initAndGuardChatSession } from "./chat-thread-service";
import { CosmosDBChatMessageHistory } from "./cosmosdb/cosmosdb";
import { PromptGPTProps } from "./models";
import { GetAPIKey } from "@/features/common/keyvault";

export const ChatAPISimple = async (props: PromptGPTProps) => {
  const { lastHumanMessage, chatThread } = await initAndGuardChatSession(props);

  const realApiKey = await GetAPIKey(chatThread.apiKey) as string;

  const openAI = OpenAIInstance(realApiKey);
  console.log("openAI", openAI.baseURL);

  
  const userId = await userHashedId();

  const chatHistory = new CosmosDBChatMessageHistory({
    sessionId: chatThread.id,
    userId: userId,
  });

  await chatHistory.addMessage({
    content: lastHumanMessage.content,
    role: "user",
  });

  const history = await chatHistory.getMessages();
  const topHistory = history.slice(history.length - 30, history.length);

  try {
    openAI.baseURL = `${process.env.AZURE_OPENAI_API_INSTANCE_NAME}/openai/deployments/${chatThread.deployment}`
    
    const response = await openAI.chat.completions.create({
      messages: [
        {
          role: "system",
          content: `-You are ${AI_NAME} who is a helpful AI Assistant.
          - You will provide clear and concise queries, and you will respond with polite and professional answers.
          - You will answer questions truthfully and accurately.`,
        },
        ...topHistory,
      ],
      model: chatThread.deployment,
      stream: true,
    });

    const stream = OpenAIStream(response, {
      async onCompletion(completion) {
        await chatHistory.addMessage({
          content: completion,
          role: "assistant",
        });
      },
    });
    return new StreamingTextResponse(stream);
  } catch (e: unknown) {
    console.error(e);
    if (e instanceof Error) {
      return new Response(e.message, {
        status: 500,
        statusText: e.toString(),
      });
    } else {
      return new Response("An unknown error occurred.", {
        status: 500,
        statusText: "Unknown Error",
      });
    }
  }
};
