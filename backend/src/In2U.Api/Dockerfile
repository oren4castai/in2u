FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY In2U.Api.csproj ./
RUN dotnet restore In2U.Api.csproj
COPY . .
RUN dotnet publish In2U.Api.csproj -c Release -o /out /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
COPY --from=build /out .
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080
ENTRYPOINT ["dotnet", "In2U.Api.dll"]
