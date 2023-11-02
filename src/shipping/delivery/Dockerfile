FROM mcr.microsoft.com/dotnet/aspnet:6.0 as base
WORKDIR /app
EXPOSE 8080

FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build

WORKDIR /app
COPY Fabrikam.DroneDelivery.Common/*.csproj ./Fabrikam.DroneDelivery.Common/
COPY Fabrikam.DroneDelivery.DeliveryService/*.csproj ./Fabrikam.DroneDelivery.DeliveryService/
WORKDIR /app
RUN dotnet restore /app/Fabrikam.DroneDelivery.Common/
RUN dotnet restore /app/Fabrikam.DroneDelivery.DeliveryService/

WORKDIR /app
COPY Fabrikam.DroneDelivery.Common/. ./Fabrikam.DroneDelivery.Common/
COPY Fabrikam.DroneDelivery.DeliveryService/. ./Fabrikam.DroneDelivery.DeliveryService/

FROM build AS testrunner

WORKDIR /app/tests
COPY Fabrikam.DroneDelivery.DeliveryService.Tests/*.csproj .
WORKDIR /app/tests
RUN dotnet restore /app/tests/

WORKDIR /app/tests
COPY Fabrikam.DroneDelivery.DeliveryService.Tests/. .
ENTRYPOINT ["dotnet", "test", "--logger:trx"]

FROM build AS publish

RUN find -type d -name bin -prune -exec rm -rf {} \; && find -type d -name obj -prune -exec rm -rf {} \;

WORKDIR /app
RUN dotnet publish /app/Fabrikam.DroneDelivery.DeliveryService/ -c release -o ./out 

FROM base AS runtime

LABEL Tags="Azure,AKS,DroneDelivery"

WORKDIR /app
COPY --from=publish /app/out ./
ENTRYPOINT ["dotnet", "Fabrikam.DroneDelivery.DeliveryService.dll"]