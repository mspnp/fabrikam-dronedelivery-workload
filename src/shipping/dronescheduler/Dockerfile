FROM mcr.microsoft.com/dotnet/aspnet:6.0 as base
WORKDIR /app
EXPOSE 80

FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build

WORKDIR /app
COPY delivery/Fabrikam.DroneDelivery.Common/*.csproj ./delivery/Fabrikam.DroneDelivery.Common/
COPY dronescheduler/Fabrikam.DroneDelivery.DroneSchedulerService/*.csproj ./dronescheduler/Fabrikam.DroneDelivery.DroneSchedulerService/
WORKDIR /app
RUN dotnet restore /app/delivery/Fabrikam.DroneDelivery.Common/
RUN dotnet restore /app/dronescheduler/Fabrikam.DroneDelivery.DroneSchedulerService/

WORKDIR /app
COPY delivery/Fabrikam.DroneDelivery.Common/. ./delivery/Fabrikam.DroneDelivery.Common/
COPY dronescheduler/Fabrikam.DroneDelivery.DroneSchedulerService/. ./dronescheduler/Fabrikam.DroneDelivery.DroneSchedulerService/

FROM build AS publish

RUN find -type d -name bin -prune -exec rm -rf {} \; && find -type d -name obj -prune -exec rm -rf {} \;

WORKDIR /app
RUN dotnet publish /app/dronescheduler/Fabrikam.DroneDelivery.DroneSchedulerService/ -c release -o ./out

FROM base AS runtime

LABEL Tags="Azure,AKS,DroneDelivery"

WORKDIR /app
COPY --from=publish /app/out ./
RUN ls -la
ENTRYPOINT ["dotnet", "Fabrikam.DroneDelivery.DroneSchedulerService.dll"]

