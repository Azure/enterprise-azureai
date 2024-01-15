using Azure.Core;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;

namespace AzureAI.Proxy.Models;

public static class OpenAIAccessToken
{
    private const string OPENAI_SCOPE = "https://cognitiveservices.azure.com/.default";

    public async static Task<string> GetAccessTokenAsync(TokenCredential managedIdenitityCredential, CancellationToken cancellationToken)
    {
        var accessToken = await managedIdenitityCredential.GetTokenAsync(
            new TokenRequestContext(
                new[] { OPENAI_SCOPE }
                ),
            cancellationToken
            );

        return accessToken.Token;
    }


    public static bool IsTokenExpired(string accessToken, string tenantId)
    {
        var tokenHandler = new JwtSecurityTokenHandler();
        var jwttoken = tokenHandler.ReadToken(accessToken);
        var expDate = jwttoken.ValidTo;

        bool result = expDate < DateTime.UtcNow;
        return result;
    }
}
