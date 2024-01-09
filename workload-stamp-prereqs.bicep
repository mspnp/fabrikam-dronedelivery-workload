targetScope = 'subscription'

param resourceGroupLocation string = 'eastus'

resource resourceGroupShippingDronedelivery 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-shipping-dronedelivery'
  location: resourceGroupLocation
  tags: {
    displayName: 'Resource Group for general purpose'
  }
}

resource resourceGroupShippingDronedeliveryAcr 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-shipping-dronedelivery-acr'
  location: resourceGroupLocation
  tags: {
    displayName: 'Container Registry Resource Group'
  }
}

module workloadStampPrereqsDep './nested_workload-stamp-prereqs.bicep' = {
  name: 'workload-stamp-prereqs-dep'
  scope: resourceGroupShippingDronedelivery
  params: {
    resourceGroupLocation: resourceGroupLocation
  }
}
