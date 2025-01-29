@description('ACR region.')
param location string = resourceGroup().location

@description('Azure Container Registry name.')
param  acrName string

resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: acrName
  sku: {
    name: 'Premium'
  }
  location: location
  tags: {
    displayName: 'Container Registry'
  }
  properties: {
    adminUserEnabled: false
    networkRuleSet: {
      defaultAction: 'Allow'
      ipRules: []
    }
    policies: {
      quarantinePolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        type: 'Notary'
        status: 'disabled'
      }
      retentionPolicy: {
        days: 15
        status: 'enabled'
      }
    }
  }
}

output acrId string = acr.id
