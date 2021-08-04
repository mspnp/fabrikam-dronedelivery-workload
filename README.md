# Fabrikam Drone Delivery - Shared services

This repository contains source files and build instructions for the containerized Fabrikam Drone Delivery application. Once all the microservices are built and pushed to your Azure Container Registry, they're ready to be pulled by any Azure service that has support for containers.

It is currently used in:
* [Microservices architecture on AKS](https://github.com/mspnp/microservices-reference-implementation)
* [Fabrikam drone delivery](https://github.com/mspnp/aks-fabrikam-dronedelivery) reference implementation.

## The Drone Delivery app

The Drone Delivery application is a sample application that consists of several microservices. Because it's a sample, the functionality is simulated, but the APIs and microservices interactions are intended to reflect real-world design patterns.

## Microservices and folder structure

- Ingestion service. Receives client requests and buffers them  (./src/shipping/ingestion)
- Workflow service. Dispatches client requests and manages the delivery workflow (./src/shipping/workflow)
- Package service. Manages packages (./src/shipping/package)
- Drone scheduler service. Schedules drones and monitors drones in flight (./src/shipping/dronescheduler)
- Delivery service. Manages deliveries that are scheduled or in-transit (./src/shipping/delivery).

## Deploy an Azure Container Registry (ACR)

### Log in to Azure CLI

```bash
az login
```

### Set the resource group variable

```bash
RESOURCE_GROUP=rg-shipping-dronedelivery
```

### Deploy the workload's prerequisites

```bash
az deployment sub create --name workload-stamp-prereqs --location eastus --template-file workload-stamp-prereqs.json --parameters resourceGroupName=$RESOURCE_GROUP resourceGroupLocation=eastus
```

### Get the Azure Container Registry and workload resource group name

```bash
ACR_RESOURCE_GROUP=$(az deployment sub show -n workload-stamp-prereqs --query properties.outputs.acrResourceGroupName.value -o tsv)
```

### Get the workload user assigned identities

```bash
DELIVERY_ID_NAME=$(az deployment group show -g $RESOURCE_GROUP -n workload-stamp-prereqs-dep --query properties.outputs.deliveryIdName.value -o tsv) && \
DELIVERY_PRINCIPAL_ID=$(az identity show -g $RESOURCE_GROUP -n $DELIVERY_ID_NAME --query principalId -o tsv) && \
DRONESCHEDULER_ID_NAME=$(az deployment group show -g $RESOURCE_GROUP -n workload-stamp-prereqs-dep --query properties.outputs.droneSchedulerIdName.value -o tsv) && \
DRONESCHEDULER_PRINCIPAL_ID=$(az identity show -g $RESOURCE_GROUP -n $DRONESCHEDULER_ID_NAME --query principalId -o tsv) && \
WORKFLOW_ID_NAME=$(az deployment group show -g $RESOURCE_GROUP -n workload-stamp-prereqs-dep --query properties.outputs.workflowIdName.value -o tsv) && \
WORKFLOW_PRINCIPAL_ID=$(az identity show -g $RESOURCE_GROUP -n $WORKFLOW_ID_NAME --query principalId -o tsv) && \
PACKAGE_ID_NAME=$(az deployment group show -g $RESOURCE_GROUP -n workload-stamp-prereqs-dep --query properties.outputs.packageIdName.value -o tsv) && \
PACKAGE_ID_PRINCIPAL_ID=$(az identity show -g $RESOURCE_GROUP -n $PACKAGE_ID_NAME --query principalId -o tsv) && \
INGESTION_ID_NAME=$(az deployment group show -g $RESOURCE_GROUP -n workload-stamp-prereqs-dep --query properties.outputs.ingestionIdName.value -o tsv) && \
INGESTION_ID_PRINCIPAL_ID=$(az identity show -g $RESOURCE_GROUP -n $INGESTION_ID_NAME --query principalId -o tsv)
```

### Deploy the workload

```bash
az deployment group create -f workload-stamp.json -g $ACR_RESOURCE_GROUP -p droneSchedulerPrincipalId=$DRONESCHEDULER_PRINCIPAL_ID \
-p workflowPrincipalId=$WORKFLOW_PRINCIPAL_ID \
-p deliveryPrincipalId=$DELIVERY_PRINCIPAL_ID \
-p ingestionPrincipalId=$INGESTION_ID_PRINCIPAL_ID \
-p packagePrincipalId=$PACKAGE_ID_PRINCIPAL_ID \
-p acrResourceGroupName=$ACR_RESOURCE_GROUP
```

### Assign ACR variables

```bash
ACR_NAME=$(az deployment group show -g  $ACR_RESOURCE_GROUP -n workload-stamp --query properties.outputs.acrName.value -o tsv)
ACR_SERVER=$(az acr show -n $ACR_NAME --query loginServer -o tsv)
```

## Build the microservice images

### Steps

1. Build the Delivery service.

```bash
az acr build -r $ACR_NAME -t $ACR_SERVER/delivery:0.1.0 ./src/shipping/delivery/.
```

2. Build the Ingestion service.

```bash
az acr build -r $ACR_NAME -t $ACR_SERVER/ingestion:0.1.0 ./src/shipping/ingestion/.
```

3. Build the Workflow service.

```bash
az acr build -r $ACR_NAME -t $ACR_SERVER/workflow:0.1.0 ./src/shipping/workflow/.
```

4. Build the DroneScheduler service.

```bash
az acr build -r $ACR_NAME -f ./src/shipping/dronescheduler/Dockerfile -t $ACR_SERVER/dronescheduler:0.1.0 ./src/shipping/.
```

5. Build the Package service.

```bash
az acr build -r $ACR_NAME -t $ACR_SERVER/package:0.1.0 ./src/shipping/package/.
```

## Contributions

Please see our [contributor guide](./CONTRIBUTING.md).

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/). For more information, see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or contact <opencode@microsoft.com> with any additional questions or comments.

With :heart: from Microsoft Patterns & Practices, [Azure Architecture Center](https://aka.ms/architecture).
