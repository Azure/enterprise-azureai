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
        new AzureKeyCredential("pascal")
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
Console.ReadLine();




