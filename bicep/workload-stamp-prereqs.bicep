targetScope = 'subscription'

param resourceGroupLocation string = 'eastus'

resource rg_shipping_dronedelivery 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-shipping-dronedelivery'
  location: resourceGroupLocation
  tags: {
    displayName: 'Resource Group for general purpose'
  }
}

resource rg_shipping_dronedelivery_acr 'Microsoft.Resources/resourceGroups@2022-09-01' = {
  name: 'rg-shipping-dronedelivery-acr'
  location: resourceGroupLocation
  tags: {
    displayName: 'Container Registry Resource Group'
  }
}

module workload_stamp_prereqs_dep './nested_workload-stamp-prereqs.bicep' = {
  name: 'workload-stamp-prereqs-dep'
  scope: resourceGroup('rg-shipping-dronedelivery')
  params: {
    resourceGroupLocation: resourceGroupLocation
  }
  dependsOn: [
    rg_shipping_dronedelivery
  ]
}
