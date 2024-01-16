using Azure;
using Azure.AI.OpenAI;
using Microsoft.Extensions.Configuration;

IConfigurationRoot config = new ConfigurationBuilder()
    .AddJsonFile("appsettings.json")
    .AddUserSecrets<Program>()
    .Build();

var proxyEndpoint = config["ProxyEndPoint"];
var apiKey = config["APIKey"];

OpenAIClient client = new OpenAIClient(
        new Uri(proxyEndpoint),
        new AzureKeyCredential(apiKey)
    );


var deploymentName = "gpt-35-turbo";
var chatMessages = new List<ChatRequestMessage>();

var systemChatMessage = new ChatRequestSystemMessage("You are a helpful AI Assistant");
var userChatMessage = new ChatRequestUserMessage("When was Microsoft Founded and what info can you give me on the founders in a maximum of 100 words");


chatMessages.Add(systemChatMessage);
chatMessages.Add(userChatMessage);

ChatCompletionsOptions completionOptions = new ChatCompletionsOptions(deploymentName, chatMessages); 
Console.WriteLine($"Using endpoint: {proxyEndpoint}");

//run the loop to hit rate-limiter
for (int i = 0; i < 7; i++)
{
   
    Console.WriteLine("Get answer to question: " + userChatMessage.Content);

    var response = await client.GetChatCompletionsAsync(completionOptions);

    Console.WriteLine("Get Chat Completion Result");
    foreach (ChatChoice choice in response.Value.Choices)
    {
        Console.WriteLine(choice.Message.Content);
    }

}
//end loop


Console.WriteLine("Get StreamingChat Completion Result");
    await foreach (StreamingChatCompletionsUpdate chatUpdate in client.GetChatCompletionsStreaming(completionOptions))
    {

        if (!string.IsNullOrEmpty(chatUpdate.ContentUpdate))
        {
            Console.Write(chatUpdate.ContentUpdate);
        }
    }
    Console.WriteLine();



//embedding
string embeddingDeploymentName = "text-embedding-ada-002";
List<string> embeddingText = new List<string>();
embeddingText.Add("When was Microsoft Founded?");

var embeddingsOptions = new EmbeddingsOptions(embeddingDeploymentName, embeddingText);
var embeddings = await client.GetEmbeddingsAsync(embeddingsOptions);
Console.WriteLine("Get Embeddings Result");
foreach (float item in embeddings.Value.Data[0].Embedding.ToArray())
{
    Console.WriteLine(item);
}





Console.ReadLine();




