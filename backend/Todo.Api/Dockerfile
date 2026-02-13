FROM mcr.microsoft.com/dotnet/sdk:10.0-preview AS build
WORKDIR /src

COPY ./backend/Todo.Api/Todo.Api.csproj ./backend/Todo.Api/
RUN dotnet restore ./backend/Todo.Api/Todo.Api.csproj

COPY . .
RUN dotnet publish ./backend/Todo.Api/Todo.Api.csproj -c Release -o /app/publish /p:UseAppHost=false

FROM mcr.microsoft.com/dotnet/aspnet:10.0-preview
WORKDIR /app
RUN apt-get update && apt-get install -y wget && rm -rf /var/lib/apt/lists/*
COPY --from=build /app/publish .

ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080

ENTRYPOINT ["dotnet", "Todo.Api.dll"]
