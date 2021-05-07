# Azure Kubernetes Service (AKS) Fabrikam Drone Delivery - Shared services

This repository contains source files for services that are shared by the [Microservices](https://github.com/mspnp/microservices-reference-implementation) and [fabrikam-drone delivery](https://github.com/mspnp/aks-fabrikam-dronedelivery) reference implementations.

## The Drone Delivery app

The Drone Delivery application is a sample application that consists of several microservices. Because it's a sample, the functionality is simulated, but the APIs and microservices interactions are intended to reflect real-world design patterns. There are two reference implementations that share the same. There two versions the basic (called microservices reference implementation) and the advanced (called fabrikam-drone delivery reference implementation), both share the same set of microservices.

## Microservices and folder structure

- Ingestion service. Receives client requests and buffers them  (./src/shipping/ingestion)
- Workflow service. Dispatches client requests and manages the delivery workflow (./src/shipping/workflow)
- Package service. Manages packages (./src/shipping/package)
- Drone scheduler service. Schedules drones and monitors drones in flight (./src/shipping/dronescheduler)
- Delivery service. Manages deliveries that are scheduled or in-transit (./src/shipping/delivery).
