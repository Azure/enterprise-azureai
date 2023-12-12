using Azure;
using Azure.AI.OpenAI;
using Microsoft.Extensions.Configuration;

IConfigurationRoot config = new ConfigurationBuilder()
    .AddJsonFile("appsettings.json")
    .AddJsonFile("appsettings.Development.json", optional: true)
    .Build();

var proxyEndpoint = config["ProxyEndPoint"];
var apiKey = config["APIKey"];

OpenAIClient client = new OpenAIClient(
        new Uri(proxyEndpoint),
        new AzureKeyCredential(apiKey)
    );


var deploymentName = "gpt-4";
var chatMessages = new List<ChatMessage>();

var systemChatMessage = new ChatMessage();
systemChatMessage.Content = "You are a helpful AI Assistant";
systemChatMessage.Role = "system";


var userChatMessage = new ChatMessage();
userChatMessage.Content = "When was Microsoft Founded?";
userChatMessage.Role = "user";


chatMessages.Add(systemChatMessage);
chatMessages.Add(userChatMessage);

ChatCompletionsOptions completionOptions = new ChatCompletionsOptions(deploymentName, chatMessages); 
Console.WriteLine($"Using endpoint: {proxyEndpoint}");

//run the loop to hit rate-limiter
//for (int i = 0; i < 50; i++)
//{
   
    Console.WriteLine("Get answer to question: " + userChatMessage.Content);



    var response = await client.GetChatCompletionsAsync(completionOptions);

    Console.WriteLine("Get Chat Completion Result");
    foreach (ChatChoice choice in response.Value.Choices)
    {
        Console.WriteLine(choice.Message.Content);
    }

    Console.WriteLine("Get StreamingChat Completion Result");
    await foreach (StreamingChatCompletionsUpdate chatUpdate in client.GetChatCompletionsStreaming(completionOptions))
    {

        if (!string.IsNullOrEmpty(chatUpdate.ContentUpdate))
        {
            Console.Write(chatUpdate.ContentUpdate);
        }
    }
    Console.WriteLine();

//}
//end loop


//embedding
string embeddingDeploymentName = "ada-002";
List<string> embeddingText = new List<string>();
embeddingText.Add("When was Microsoft Founded?");

var embeddingsOptions = new EmbeddingsOptions();
embeddingsOptions.DeploymentName = embeddingDeploymentName;
embeddingsOptions.Input = embeddingText;
var embeddings = await client.GetEmbeddingsAsync(embeddingsOptions);
Console.WriteLine("Get Embeddings Result");
foreach (float item in embeddings.Value.Data[0].Embedding.ToArray())
{
    Console.WriteLine(item);
}

//Image Generation - proxy not done yet
//ImageGenerationOptions imageGenerationOptions = new ImageGenerationOptions();
//imageGenerationOptions.Prompt = "Logo of Microsoft projected on a map of the Netherlands";
//imageGenerationOptions.ImageCount = 2;

//Console.WriteLine("Get ImageGeneration Result");
//var images = await client.GetImageGenerationsAsync(imageGenerationOptions);




Console.ReadLine();




