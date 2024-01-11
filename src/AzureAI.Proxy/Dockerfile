#See https://aka.ms/customizecontainer to learn how to customize your debug container and how Visual Studio uses this Dockerfile to build your images for faster debugging.


FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src
COPY ["AzureAI.Proxy/AzureAI.Proxy.csproj", "AzureAI.Proxy/"]
RUN dotnet restore "./AzureAI.Proxy/./AzureAI.Proxy.csproj"
COPY . .
WORKDIR "/src/AzureAI.Proxy"
RUN dotnet build "./AzureAI.Proxy.csproj" -c $BUILD_CONFIGURATION -o /app/build

FROM build AS publish
ARG BUILD_CONFIGURATION=Release
RUN dotnet publish "./AzureAI.Proxy.csproj" -c $BUILD_CONFIGURATION -o /app/publish 

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app
EXPOSE 8080
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet","./AzureAI.Proxy.dll"]