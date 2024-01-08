#See https://aka.ms/customizecontainer to learn how to customize your debug container and how Visual Studio uses this Dockerfile to build your images for faster debugging.


FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
ARG BUILD_CONFIGURATION=Release
WORKDIR /src
COPY ["Azure.OpenAI.ChargebackProxy/Azure.OpenAI.ChargebackProxy.csproj", "Azure.OpenAI.ChargebackProxy/"]
RUN dotnet restore "./Azure.OpenAI.ChargebackProxy/./Azure.OpenAI.ChargebackProxy.csproj"
COPY . .
WORKDIR "/src/Azure.OpenAI.ChargebackProxy"
RUN dotnet build "./Azure.OpenAI.ChargebackProxy.csproj" -c $BUILD_CONFIGURATION -o /app/build

FROM build AS publish
ARG BUILD_CONFIGURATION=Release
RUN dotnet publish "./Azure.OpenAI.ChargebackProxy.csproj" -c $BUILD_CONFIGURATION -o /app/publish 

FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS final
WORKDIR /app
EXPOSE 8080
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet","./Azure.OpenAI.ChargebackProxy.dll"]