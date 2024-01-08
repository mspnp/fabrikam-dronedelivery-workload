param location string = resourceGroup().location

@description('For Azure resources that support native geo-redundancy, provide the location the redundant service will have its secondary. Should be different than the location parameter and ideally should be a paired region - https://learn.microsoft.com/azure/best-practices-availability-paired-regions. This region does not need to support availability zones.')
@allowed([
  'australiasoutheast'
  'canadaeast'
  'eastus2'
  'westus'
  'centralus'
  'westcentralus'
  'francesouth'
  'germanynorth'
  'westeurope'
  'ukwest'
  'northeurope'
  'japanwest'
  'southafricawest'
  'northcentralus'
  'eastasia'
  'eastus'
  'westus2'
  'francecentral'
  'uksouth'
  'japaneast'
  'southeastasia'
])
param geoRedundancyLocation string = 'centralus'
param droneSchedulerPrincipalId string
param workflowPrincipalId string
param deliveryPrincipalId string
param ingestionPrincipalId string
param packagePrincipalId string

var acrName = uniqueString('acr-', subscription().subscriptionId, resourceGroup().id)
var deliveryRedisCacheSKU = 'Basic'
var deliveryRedisCacheFamily = 'C'
var deliveryRedisCacheCapacity = 0
var deliveryCosmosDbName = 'd-${uniqueString(resourceGroup().id)}'
var packageMongoDbName = 'p-${uniqueString(resourceGroup().id)}'
var droneSchedulerCosmosDbName = 'ds-${uniqueString(resourceGroup().id)}'
var deliveryRedisName = 'dr-${uniqueString(resourceGroup().id)}'
var deliveryKeyVaultName = 'dkv-${uniqueString(resourceGroup().id)}'
var keyVaultPackageName = 'pkkv-${uniqueString(resourceGroup().id)}'
var ingestionSBNamespaceName = 'i-${uniqueString(resourceGroup().id)}'
var ingestionSBNamespaceSKU = 'Premium'
var ingestionSBNamespaceTier = 'Premium'
var ingestionSBName = 'i-${uniqueString(resourceGroup().id)}'
var ingestionServiceAccessKeyName = 'IngestionServiceAccessKey'
var ingestionKeyVaultName = 'ingkv-${uniqueString(resourceGroup().id)}'
var droneSchedulerKeyVaultName = 'ds-${uniqueString(resourceGroup().id)}'
var workflowKeyVaultName = 'wf-${uniqueString(resourceGroup().id)}'
var workflowServiceAccessKeyName = 'WorkflowServiceAccessKey'
var appInsightsName = 'ai-${uniqueString(resourceGroup().id)}'
var logAnaliticWorkpaceName = 'law-${uniqueString(resourceGroup().id)}'
var nestedACRDeploymentName = '${resourceGroup().name}-acr-deployment'

@description('Built-in Role: Reader - https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#reader')
resource builtInReaderRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
  scope: subscription()
}

module containerRegistry './nested_workload-stamp.bicep' = {
  name: nestedACRDeploymentName
  scope: resourceGroup('rg-shipping-dronedelivery-acr')
  params: {
    location: location
    acrName: acrName
    geoRedundancyLocation: geoRedundancyLocation
  }
  dependsOn: []
}

resource deliveryRedis 'Microsoft.Cache/Redis@2020-06-01' = {
  name: deliveryRedisName
  location: location
  tags: {
    displayName: 'Redis Cache for inflight deliveries'
    app: 'fabrikam-delivery'
    TODO: 'add log analytics resource'
  }
  properties: {
    sku: {
      capacity: deliveryRedisCacheCapacity
      family: deliveryRedisCacheFamily
      name: deliveryRedisCacheSKU
    }
  }
  dependsOn: []
}

resource deliveryCosmosDb 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: deliveryCosmosDbName
  location: location
  tags: {
    displayName: 'Delivery Cosmos Db'
    app: 'fabrikam-delivery'
  }
  properties: {
    databaseAccountOfferType: 'Standard'
    isVirtualNetworkFilterEnabled: false
    virtualNetworkRules: []
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
  }
  dependsOn: []
}

resource packageMongoDb 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: packageMongoDbName
  kind: 'MongoDB'
  location: location
  tags: {
    displayName: 'Package Cosmos Db'
    app: 'fabrikam-package'
  }
  properties: {
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
    databaseAccountOfferType: 'Standard'
    isVirtualNetworkFilterEnabled: false
    virtualNetworkRules: []
  }
  dependsOn: []
}

resource droneSchedulerCosmosDb 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: droneSchedulerCosmosDbName
  location: location
  tags: {
    displayName: 'Drone Scheduler Cosmos Db'
    app: 'fabrikam-dronescheduler'
  }
  properties: {
    databaseAccountOfferType: 'Standard'
    isVirtualNetworkFilterEnabled: false
    virtualNetworkRules: []
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
  }
  dependsOn: []
}

resource ingestionSBNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: ingestionSBNamespaceName
  location: location
  sku: {
    name: ingestionSBNamespaceSKU
    tier: ingestionSBNamespaceTier
  }
  tags: {
    displayName: 'Ingestion and Workflow Service Bus'
    app: 'fabrikam-ingestion and fabrikam-workflow'
    'app-producer': 'fabrikam-ingestion'
    'app-consumer': 'fabrikam-workflow'
  }
}

resource ingestionSBNamespace_ingestionSB 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: ingestionSBNamespace
  name: ingestionSBName
  properties: {
    lockDuration: 'PT5M'
    maxSizeInMegabytes: 1024
  }
}

resource ingestionSBNamespace_ingestionServiceAccessKey 'Microsoft.ServiceBus/namespaces/AuthorizationRules@2022-10-01-preview' = {
  parent: ingestionSBNamespace
  name: ingestionServiceAccessKeyName
  properties: {
    rights: [
      'Send'
    ]
  }
}

resource ingestionSBNamespace_workflowServiceAccessKey 'Microsoft.ServiceBus/namespaces/AuthorizationRules@2022-10-01-preview' = {
  parent: ingestionSBNamespace
  name: workflowServiceAccessKeyName
  properties: {
    rights: [
      'Listen'
    ]
  }
}

resource deliveryKeyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: deliveryKeyVaultName
  location: location
  tags: {
    displayName: 'Delivery Key Vault'
    app: 'fabrikam-delivery'
  }
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      virtualNetworkRules: []
    }
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: deliveryPrincipalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
  dependsOn: []
}

resource deliveryKeyVaultName_CosmosDB_Endpoint 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: deliveryKeyVault
  name: 'CosmosDB-Endpoint'
  properties: {
    value: deliveryCosmosDb.properties.documentEndpoint
  }
}

resource deliveryKeyVaultName_CosmosDB_Key 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: deliveryKeyVault
  name: 'CosmosDB-Key'
  properties: {
    value: listKeys(deliveryCosmosDb.id, '2016-03-31').primaryMasterKey
  }
}

resource deliveryKeyVaultName_Redis_Endpoint 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: deliveryKeyVault
  name: 'Redis-Endpoint'
  properties: {
    value: deliveryRedis.properties.hostName
  }
}

resource deliveryKeyVaultName_Redis_AccessKey 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: deliveryKeyVault
  name: 'Redis-AccessKey'
  properties: {
    value: listKeys(deliveryRedis.id, '2016-04-01').primaryKey
  }
}

resource deliveryKeyVaultName_ApplicationInsights_InstrumentationKey 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: deliveryKeyVault
  name: 'ApplicationInsights--InstrumentationKey'
  properties: {
    value: reference(appInsights.id, '2015-05-01').InstrumentationKey
  }
}

resource keyVaultPackage 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: keyVaultPackageName
  location: location
  tags: {
    displayName: 'Package Key Vault'
    app: 'fabrikam-package'
  }
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      virtualNetworkRules: []
    }
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: packagePrincipalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
  dependsOn: []
}

resource keyVaultPackageName_ApplicationInsights_InstrumentationKey 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: keyVaultPackage 
  name: 'ApplicationInsights--InstrumentationKey'
  properties: {
    value: reference(appInsights.id, '2015-05-01').InstrumentationKey
  }
}

resource ingestionKeyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: ingestionKeyVaultName
  location: location
  tags: {
    displayName: 'Ingestion Key Vault'
    app: 'fabrikam-ingestion'
  }
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      virtualNetworkRules: []
    }
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: ingestionPrincipalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
  dependsOn: []
}

resource ingestionKeyVaultName_ApplicationInsights_InstrumentationKey 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: ingestionKeyVault
  name: 'ApplicationInsights--InstrumentationKey'
  properties: {
    value: reference(appInsights.id, '2015-05-01').InstrumentationKey
  }
}

resource ingestionKeyVaultName_Queue_Key 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: ingestionKeyVault
  name: 'Queue--Key'
  properties: {
    value: listKeys(ingestionSBNamespace_ingestionServiceAccessKey.id, '2017-04-01').primaryKey
  }
}

resource droneSchedulerKeyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: droneSchedulerKeyVaultName
  location: location
  tags: {
    displayName: 'DroneScheduler Key Vault'
    app: 'fabrikam-dronescheduler'
  }
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      virtualNetworkRules: []
    }
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: droneSchedulerPrincipalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
  dependsOn: []
}

resource droneSchedulerKeyVaultName_ApplicationInsights_InstrumentationKey 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: droneSchedulerKeyVault
  name: 'ApplicationInsights--InstrumentationKey'
  properties: {
    value: reference(appInsights.id, '2015-05-01').InstrumentationKey
  }
}

resource droneSchedulerKeyVaultName_CosmosDBEndpoint 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  parent: droneSchedulerKeyVault
  name: 'CosmosDBEndpoint'
  properties: {
    value: droneSchedulerCosmosDb.properties.documentEndpoint
  }
}

resource droneSchedulerKeyVaultName_CosmosDBKey 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  parent: droneSchedulerKeyVault
  name: 'CosmosDBKey'
  properties: {
    value: listKeys(droneSchedulerCosmosDb.id, '2016-03-31').primaryMasterKey
  }
}

resource droneSchedulerKeyVaultName_CosmosDBConnectionMode 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: droneSchedulerKeyVault
  name: 'CosmosDBConnectionMode'
  properties: {
    value: 'Gateway'
  }
}

resource droneSchedulerKeyVaultName_CosmosDBConnectionProtocol 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: droneSchedulerKeyVault
  name: 'CosmosDBConnectionProtocol'
  properties: {
    value: 'Https'
  }
}

resource droneSchedulerKeyVaultName_CosmosDBMaxConnectionsLimit 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: droneSchedulerKeyVault
  name: 'CosmosDBMaxConnectionsLimit'
  properties: {
    value: '50'
  }
}

resource droneSchedulerKeyVaultName_CosmosDBMaxParallelism 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: droneSchedulerKeyVault
  name: 'CosmosDBMaxParallelism'
  properties: {
    value: '-1'
  }
}

resource droneSchedulerKeyVaultName_CosmosDBMaxBufferedItemCount 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: droneSchedulerKeyVault
  name: 'CosmosDBMaxBufferedItemCount'
  properties: {
    value: '0'
  }
}

resource droneSchedulerKeyVaultName_FeatureManagement_UsePartitionKey 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: droneSchedulerKeyVault
  name: 'FeatureManagement--UsePartitionKey'
  properties: {
    value: 'false'
  }
}

resource workflowKeyVault 'Microsoft.KeyVault/vaults@2022-07-01' = {
  name: workflowKeyVaultName
  location: location
  tags: {
    displayName: 'Workflow Key Vault'
    app: 'fabrikam-workflow'
  }
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Allow'
      virtualNetworkRules: []
    }
    accessPolicies: [
      {
        tenantId: subscription().tenantId
        objectId: workflowPrincipalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }
  dependsOn: []
}

resource workflowKeyVaultName_Queue 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: workflowKeyVault
  name: 'QueueName'
  properties: {
    value: ingestionSBName
  }
}

resource workflowKeyVaultName_QueueEndpoint 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: workflowKeyVault
  name: 'QueueEndpoint'
  properties: {
    value: ingestionSBNamespace.properties.serviceBusEndpoint
  }
}

resource workflowKeyVaultName_QueueAccessPolicy 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: workflowKeyVault
  name: 'QueueAccessPolicyName'
  properties: {
    value: workflowServiceAccessKeyName
  }
}

resource workflowKeyVaultName_QueueAccessPolicyKey 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: workflowKeyVault
  name: 'QueueAccessPolicyKey'
  properties: {
    value: listkeys(ingestionSBNamespace_workflowServiceAccessKey.id, '2017-04-01').primaryKey
  }
}

resource workflowKeyVaultName_ApplicationInsights_InstrumentationKey 'Microsoft.KeyVault/vaults/secrets@2022-07-01' = {
  parent: workflowKeyVault
  name: 'ApplicationInsights--InstrumentationKey'
  properties: {
    value: reference(appInsights.id, '2015-05-01').InstrumentationKey
  }
}

resource LogAnaliticWorkpace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnaliticWorkpaceName
  location: location
  properties: {
    sku: {
      name: 'pergb2018'
    }
    publicNetworkAccessForIngestion:'Enabled'
    publicNetworkAccessForQuery:'Enabled'
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  kind: 'other'
  location: location
  tags: {
    displayName: 'App Insights instance - Distributed Tracing'
  }
  properties: {
    Application_Type: 'other'
    WorkspaceResourceId: LogAnaliticWorkpace.id
    IngestionMode:'LogAnalytics'
    publicNetworkAccessForIngestion:'Enabled'
    publicNetworkAccessForQuery:'Enabled'
  }
}

resource deliveryKeyVaultName_Microsoft_Authorization_deliveryIdName_id_readerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name:  guid('${deliveryKeyVaultName}${resourceGroup().id}', builtInReaderRole.id)
  scope: deliveryKeyVault
  properties: {
    roleDefinitionId: builtInReaderRole.id
    principalId: deliveryPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource workflowKeyVaultName_Microsoft_Authorization_workflowIdName_id_readerRole 'Microsoft.Authorization/roleAssignments@2022-04-01'= {
  name: guid('${workflowKeyVaultName}${resourceGroup().id}', builtInReaderRole.id)
  scope: workflowKeyVault
  properties: {
    roleDefinitionId: builtInReaderRole.id
    principalId: workflowPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource droneSchedulerKeyVaultName_Microsoft_Authorization_droneSchedulerIdName_id_readerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${droneSchedulerKeyVaultName}${resourceGroup().id}', builtInReaderRole.id)
  scope: droneSchedulerKeyVault
  properties: {
    roleDefinitionId: builtInReaderRole.id
    principalId: droneSchedulerPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource ingestionKeyVaultName_Microsoft_Authorization_ingestionIdName_id_readerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${ingestionKeyVaultName}${resourceGroup().id}', builtInReaderRole.id)
  scope: ingestionKeyVault
  properties: {
    roleDefinitionId: builtInReaderRole.id
    principalId: ingestionPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource keyVaultPackageName_Microsoft_Authorization_packageIdName_id_readerRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('${keyVaultPackageName}${resourceGroup().id}', builtInReaderRole.id)
  scope: keyVaultPackage
  properties: {
    roleDefinitionId: builtInReaderRole.id
    principalId: packagePrincipalId
    principalType: 'ServicePrincipal'
  }
}

output acrId string = containerRegistry.outputs.acrId
output acrName string = acrName
output deliveryKeyVaultUri string = deliveryKeyVault.properties.vaultUri
output droneSchedulerKeyVaultUri string = droneSchedulerKeyVault.properties.vaultUri
output deliveryCosmosDbName string = deliveryCosmosDbName
output droneSchedulerCosmosDbName string = droneSchedulerCosmosDbName
output packageMongoDbName string = packageMongoDbName
output ingestionQueueNamespace string = ingestionSBNamespaceName
output ingestionQueueName string = ingestionSBName
output ingestionServiceAccessKeyName string = ingestionServiceAccessKeyName
output workflowKeyVaultName string = workflowKeyVaultName
output deliveryKeyVaultName string = deliveryKeyVaultName
output droneSchedulerKeyVaultName string = droneSchedulerKeyVaultName
output ingestionKeyVaultName string = ingestionKeyVaultName
output keyVaultPackageName string = keyVaultPackageName
output appInsightsName string = appInsightsName
