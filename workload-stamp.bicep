targetScope = 'resourceGroup'

/*** PARAMETERS ***/

@description('The default location for all resources.')
@minLength(1)
param location string = resourceGroup().location

/*** VARIABLES ***/

var commonUniqueString = uniqueString('fabrikam', resourceGroup().id)

/*** EXISTING RESOURCES ***/

@description('Built-in Role: Reader - https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#reader')
resource builtInReaderRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  name: 'acdd72a7-3385-48ef-bd42-f606fba81ae7'
  scope: subscription()
}

/*** RESOURCES (Shared for all services) ***/

@description('Log analytics workspace used for Application Insights and Azure Diagnostics for all resources.')
resource la 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: 'la-shipping-dronedelivery'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
    workspaceCapping: {
      dailyQuotaGb: -1
    }
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
}

@description('The Azure Container Registry expected to hold all of the workload images.')
resource acr 'Microsoft.ContainerRegistry/registries@2023-01-01-preview' = {
  name: 'acr${commonUniqueString}'
  sku: {
    name: 'Premium'
  }
  location: location
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

@description('Azure Container Registry diagnostics settings.')
resource dsAcr 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: acr
  properties: {
    workspaceId: la.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

@description('Application Insights sink for all services')
resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: 'ai-${commonUniqueString}'
  kind: 'other'
  location: location
  tags: {
    displayName: 'App Insights instance - Distributed Tracing'
  }
  properties: {
    Application_Type: 'other'
    DisableIpMasking: false
    DisableLocalAuth: false
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
    WorkspaceResourceId: la.id
  }
}

/*** RESOURCES (Workflow service) ***/

@description('Managed identity for the Workflow service.')
resource miWorkflow 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'mi-workflow'
  location: location
  tags: {
    displayName: 'Workflow service managed identity'
    what: 'rbac'
    reason: 'workload-identity'
    app: 'fabrikam-workflow'
  }
}

@description('Key Vault instance used by the Workflow service.')
resource kvWorkflow 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: 'kv-wf-${commonUniqueString}'
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
    createMode: 'default'
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableRbacAuthorization: false  // TODO: Convert to RBAC
    tenantId: subscription().tenantId
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
    accessPolicies: [
      // TODO: Convert to RBAC
      {
        tenantId: subscription().tenantId
        objectId: miWorkflow.properties.principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }

  // TODO: This is not a secret and shouldn't be in Key Vault
  resource secretQueueName 'secrets' = {
    name: 'QueueName'
    properties: {
      value: sbnIngestion::ingestionQueue.name
    }
  }

  // TODO: This is not a secret and shouldn't be in Key Vault
  resource secretQueueEndpoint 'secrets' = {
    name: 'QueueEndpoint'
    properties: {
      value: sbnIngestion.properties.serviceBusEndpoint
    }
  }

  // TODO: This is not a secret and shouldn't be in Key Vault
  resource secretQueueAccessPolicy 'secrets' = {
    name: 'QueueAccessPolicyName'
    properties: {
      value: sbnIngestion::workflowAccessKey.name
    }
  }

  resource secretQueueAccessPolicyKey 'secrets' = {
    name: 'QueueAccessPolicyKey'
    properties: {
      value: sbnIngestion::workflowAccessKey.listKeys().primaryKey
    }
  }

  resource secretApplicationInsights 'secrets' = {
    name: 'ApplicationInsights--InstrumentationKey'
    properties: {
      value: reference(appInsights.id, '2015-05-01').InstrumentationKey
    }
  }
}

@description('Key Vault diagnostics settings.')
resource dsKvWorkflow 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: kvWorkflow
  properties: {
    workspaceId: la.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

@description('Gives Workflow service identity ability to see its Key Vault instance.')
resource rsWorkflowToKeyVault 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(miWorkflow.id, builtInReaderRole.id, kvWorkflow.id)
  scope: kvWorkflow
  properties: {
    principalId: miWorkflow.properties.principalId
    roleDefinitionId: builtInReaderRole.id
    principalType: 'ServicePrincipal'
  }
}

/*** RESOURCES (Delivery service) ***/

@description('Managed identity for the Delivery service.')
resource miDelivery 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'mi-delivery'
  location: location
  tags: {
    displayName: 'Delivery service managed identity'
    what: 'rbac'
    reason: 'workload-identity'
    app: 'fabrikam-delivery'
  }
}

@description('Redis Cache instance for the Delivery service')
resource redisDelivery 'Microsoft.Cache/redis@2022-06-01' = {
  name: 'redis-d-${commonUniqueString}'
  location: location
  tags: {
    displayName: 'Redis Cache for inflight deliveries'
    app: 'fabrikam-delivery'
  }
  properties: {
    enableNonSslPort: false
    sku: {
      capacity: 0
      family: 'C'
      name: 'Basic'
    }
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    subnetId: null
  }
  dependsOn: []
}

@description('Redis Cache diagnostics settings.')
resource dsRedisDelivery 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: redisDelivery
  properties: {
    workspaceId: la.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

@description('Database for the Delivery service.')
resource cosmosDbDelivery 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: 'cosmos-d-${commonUniqueString}'
  location: location
  kind: 'GlobalDocumentDB'
  tags: {
    displayName: 'Delivery Cosmos DB'
    app: 'fabrikam-delivery'
  }
  properties: {
    createMode: 'Default'
    databaseAccountOfferType: 'Standard'
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    disableLocalAuth: false
    enableCassandraConnector: false
    enableFreeTier: false
    minimalTlsVersion: 'Tls12'
    publicNetworkAccess: 'Enabled'
    ipRules: []
    isVirtualNetworkFilterEnabled: false
    virtualNetworkRules: []
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
  }
}

@description('CosmosDB diagnostics settings.')
resource dsCosmosDbDelivery 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: cosmosDbDelivery
  properties: {
    workspaceId: la.id
    logs: [
      {
        category: 'DataPlaneRequests'
        enabled: true
      }
      {
        category: 'ControlPlaneRequests'
        enabled: true
      }
      {
        category: 'QueryRuntimeStatistics'
        enabled: true
      }
    ]
  }
}

@description('Key Vault instance used by the Delivery service.')
resource kvDelivery 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: 'kv-d-${commonUniqueString}'
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
    createMode: 'default'
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableRbacAuthorization: false  // TODO: Convert to RBAC
    tenantId: subscription().tenantId
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
    accessPolicies: [
      // TODO: Convert to RBAC
      {
        tenantId: subscription().tenantId
        objectId: miDelivery.properties.principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }

  resource secretCosmosDbEndpoint 'secrets' = {
    name: 'CosmosDB-Endpoint'
    properties: {
      value: cosmosDbDelivery.properties.documentEndpoint
    }
  }

  resource secretCosmosDbKey 'secrets' = {
    name: 'CosmosDB-Key'
    properties: {
      value: cosmosDbDelivery.listKeys().primaryMasterKey
    }
  }

  resource secretRedisEndpoint 'secrets' = {
    name: 'Redis-Endpoint'
    properties: {
      value: redisDelivery.properties.hostName
    }
  }

  resource secretRedisAccessKey 'secrets' = {
    name: 'Redis-AccessKey'
    properties: {
      value: redisDelivery.listKeys().primaryKey
    }
  }

  resource secretApplicationInsightsKey 'secrets' = {
    name: 'ApplicationInsights--InstrumentationKey'
    properties: {
      value: appInsights.properties.InstrumentationKey
    }
  }
}

@description('Key Vault diagnostics settings.')
resource dsKvDelivery 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: kvDelivery
  properties: {
    workspaceId: la.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

@description('Gives Delivery service identity ability to see its Key Vault instance.')
resource rsDeliveryToKeyVault 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(miDelivery.id, builtInReaderRole.id, kvDelivery.id)
  scope: kvDelivery
  properties: {
    principalId: miDelivery.properties.principalId
    roleDefinitionId: builtInReaderRole.id
    principalType: 'ServicePrincipal'
  }
}

/*** RESOURCES (Scheduler service) ***/

@description('Managed identity for the Scheduler service.')
resource miDroneScheduler 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'mi-dronescheduler'
  location: location
  tags: {
    displayName: 'Scheduler service managed identity'
    what: 'rbac'
    reason: 'workload-identity'
    app: 'fabrikam-dronescheduler'
  }
}

@description('Database for the Scheduler service.')
resource cosmosDbDroneScheduler 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: 'cosmos-ds-${commonUniqueString}'
  location: location
  kind: 'GlobalDocumentDB'
  tags: {
    displayName: 'Drone Scheduler Cosmos DB'
    app: 'fabrikam-dronescheduler'
  }
  properties: {
    createMode: 'Default'
    databaseAccountOfferType: 'Standard'
    disableLocalAuth: false
    consistencyPolicy: {
      defaultConsistencyLevel: 'Session'
    }
    enableCassandraConnector: false
    enableFreeTier: false
    minimalTlsVersion: 'Tls12'
    publicNetworkAccess: 'Enabled'
    ipRules: []
    isVirtualNetworkFilterEnabled: false
    virtualNetworkRules: []
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
  }
}

@description('CosmosDB diagnostics settings.')
resource dsCosmosDbDroneScheduler 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: cosmosDbDroneScheduler
  properties: {
    workspaceId: la.id
    logs: [
      {
        category: 'DataPlaneRequests'
        enabled: true
      }
      {
        category: 'ControlPlaneRequests'
        enabled: true
      }
      {
        category: 'QueryRuntimeStatistics'
        enabled: true
      }
    ]
  }
}

@description('Key Vault instance used by the Scheduler service.')
resource kvDroneScheduler 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: 'kv-ds-${commonUniqueString}'
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
    createMode: 'default'
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableRbacAuthorization: false  // TODO: Convert to RBAC
    tenantId: subscription().tenantId
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
    accessPolicies: [
      // TODO: Convert to RBAC
      {
        tenantId: subscription().tenantId
        objectId: miDroneScheduler.properties.principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }

  resource secretApplicationInsights 'secrets' = {
    name: 'ApplicationInsights--InstrumentationKey'
    properties: {
      value: reference(appInsights.id, '2015-05-01').InstrumentationKey
    }
  }
  
  // TODO: This is not a secret and shouldn't be in Key Vault
  resource secretCosmosDBEndpoint 'secrets' = {
    name: 'CosmosDBEndpoint'
    properties: {
      value: cosmosDbDroneScheduler.properties.documentEndpoint
    }
  }
  
  resource secretCosmosDBKey 'secrets' = {
    name: 'CosmosDBKey'
    properties: {
      value: cosmosDbDroneScheduler.listKeys().primaryMasterKey
    }
  }

  // TODO: This is not a secret and shouldn't be in Key Vault
  resource secretCosmosDBConnectionMode 'secrets' = {
    name: 'CosmosDBConnectionMode'
    properties: {
      value: 'Gateway'
    }
  }
  
  // TODO: This is not a secret and shouldn't be in Key Vault
  resource secretCosmosDBConnectionProtocol 'secrets' = {
    name: 'CosmosDBConnectionProtocol'
    properties: {
      value: 'Https'
    }
  }
  
  // TODO: This is not a secret and shouldn't be in Key Vault
  resource secretCosmosDBMaxConnectionsLimit 'secrets' = {
    name: 'CosmosDBMaxConnectionsLimit'
    properties: {
      value: '50'
    }
  }
  
  // TODO: This is not a secret and shouldn't be in Key Vault
  resource secretCosmosDBMaxParallelism 'secrets' = {
    name: 'CosmosDBMaxParallelism'
    properties: {
      value: '-1'
    }
  }
  
  // TODO: This is not a secret and shouldn't be in Key Vault
  resource secretCosmosDBMaxBufferedItemCount 'secrets' = {
    name: 'CosmosDBMaxBufferedItemCount'
    properties: {
      value: '0'
    }
  }
  
  // TODO: This is not a secret and shouldn't be in Key Vault
  resource secretFeatureManagementUsePartitionKey 'secrets' = {
    name: 'FeatureManagement--UsePartitionKey'
    properties: {
      value: 'false'
    }
  }
}

@description('Key Vault diagnostics settings.')
resource dsKvDroneScheduler 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: kvDroneScheduler
  properties: {
    workspaceId: la.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

@description('Gives Scheduler service identity ability to see its Key Vault instance.')
resource rsSchedulerToKeyVault 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(miDroneScheduler.id, builtInReaderRole.id, kvDroneScheduler.id)
  scope: kvDroneScheduler
  properties: {
    principalId: miDroneScheduler.properties.principalId
    roleDefinitionId: builtInReaderRole.id
    principalType: 'ServicePrincipal'
  }
}

/*** RESOURCES (Ingestion service) ***/

@description('Managed identity for the Ingestion service.')
resource miIngestion 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'mi-ingestion'
  location: location
  tags: {
    displayName: 'Ingestion service managed identity'
    what: 'rbac'
    reason: 'workload-identity'
    app: 'fabrikam-ingestion'
  }
}

@description('Service Bus Namespace for the Ingestion service')
resource sbnIngestion 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' = {
  name: 'sbns-i-${commonUniqueString}'
  location: location
  sku: {
    name: 'Premium'
    tier: 'Premium'
  }
  tags: {
    displayName: 'Ingestion and Workflow Service Bus'
    app: 'fabrikam-ingestion and fabrikam-workflow'
    'app-producer': 'fabrikam-ingestion'
    'app-consumer': 'fabrikam-workflow'
  }
  properties: {
    disableLocalAuth: false
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
    zoneRedundant: true
  }

  // The queue shared between the ingestion service (send) and the workflow service (listen)
  resource ingestionQueue 'queues' = {
    name: 'sbq-i-${commonUniqueString}'
    properties: {
      lockDuration: 'PT5M'
      maxSizeInMegabytes: 1024
    }
  }

  // Allow Ingestion service to send
  resource ingestionAccessKey 'AuthorizationRules' = {
    name: 'IngestionServiceAccessKey'
    properties: {
      rights: [
        'Send'
      ]
    }
  }

  // Allow Workflow service to listen
  resource workflowAccessKey 'AuthorizationRules' = {
    name: 'WorkflowServiceAccessKey'
    properties: {
      rights: [
        'Listen'
      ]
    }
  }
}

@description('Service Bus Namepsace diagnostics settings.')
resource dsSbnIngestion 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: sbnIngestion
  properties: {
    workspaceId: la.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

@description('Key Vault instance used by the Ingestion service.')
resource kvIngestion 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: 'kv-i-${commonUniqueString}'
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
    createMode: 'default'
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableRbacAuthorization: false  // TODO: Convert to RBAC
    tenantId: subscription().tenantId
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
    accessPolicies: [
      // TODO: Convert to RBAC
      {
        tenantId: subscription().tenantId
        objectId: miIngestion.properties.principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }

  resource secretQueueKey 'secrets' = {
    name: 'Queue--Key'
    properties: {
      value: sbnIngestion::ingestionAccessKey.listKeys().primaryKey
    }
  }

  resource secretApplicationInsightsKey 'secrets' = {
    name: 'ApplicationInsights--InstrumentationKey'
    properties: {
      value: appInsights.properties.InstrumentationKey
    }
  }
}

@description('Key Vault diagnostics settings.')
resource dsKvIngestion 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: kvIngestion
  properties: {
    workspaceId: la.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

@description('Gives Ingestion service identity ability to see its Key Vault instance.')
resource rsIngestionKeyVault 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(miIngestion.id, builtInReaderRole.id, kvIngestion.id)
  scope: kvIngestion
  properties: {
    principalId: miIngestion.properties.principalId
    roleDefinitionId: builtInReaderRole.id
    principalType: 'ServicePrincipal'
  }
}

/*** RESOURCES (Package service) ***/

@description('Managed identity for the Package service.')
resource miPackage 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'mi-package'
  location: location
  tags: {
    displayName: 'Package service managed identity'
    what: 'rbac'
    reason: 'workload-identity'
    app: 'fabrikam-package'
  }
}

@description('Database for the Package service.')
resource mongoDbPackage 'Microsoft.DocumentDB/databaseAccounts@2023-04-15' = {
  name: 'cosmon-p-${commonUniqueString}'
  kind: 'MongoDB'
  location: location
  tags: {
    displayName: 'Package Cosmos DB'
    app: 'fabrikam-package'
  }
  properties: {
    createMode: 'Default'
    databaseAccountOfferType: 'Standard'
    disableLocalAuth: false
    enableCassandraConnector: false
    enableFreeTier: false
    minimalTlsVersion: 'Tls12'
    publicNetworkAccess: 'Enabled'
    ipRules: []
    isVirtualNetworkFilterEnabled: false
    virtualNetworkRules: []
    locations: [
      {
        locationName: location
        failoverPriority: 0
      }
    ]
  }
}

@description('CosmosDB diagnostics settings.')
resource dsMongoDbPackage 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: mongoDbPackage
  properties: {
    workspaceId: la.id
    logs: [
      {
        category: 'DataPlaneRequests'
        enabled: true
      }
      {
        category: 'MongoRequests'
        enabled: true
      }
      {
        category: 'ControlPlaneRequests'
        enabled: true
      }
      {
        category: 'QueryRuntimeStatistics'
        enabled: true
      }
    ]
  }
}

@description('Key Vault instance used by the Package service.')
resource kvPackage 'Microsoft.KeyVault/vaults@2023-02-01' = {
  name: 'kv-p-${commonUniqueString}'
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
    createMode: 'default'
    enabledForDeployment: false
    enabledForDiskEncryption: false
    enabledForTemplateDeployment: false
    enableRbacAuthorization: false  // TODO: Convert to RBAC
    tenantId: subscription().tenantId
    networkAcls: {
      bypass: 'None'
      defaultAction: 'Allow'
      ipRules: []
      virtualNetworkRules: []
    }
    accessPolicies: [
      // TODO: Convert to RBAC
      {
        tenantId: subscription().tenantId
        objectId: miPackage.properties.principalId
        permissions: {
          secrets: [
            'get'
            'list'
          ]
        }
      }
    ]
  }

  resource secretApplicationInsightsKey 'secrets' = {
    name: 'ApplicationInsights--InstrumentationKey'
    properties: {
      value: appInsights.properties.InstrumentationKey
    }
  }
}

@description('Key Vault diagnostics settings.')
resource dsKvPackage 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'default'
  scope: kvPackage
  properties: {
    workspaceId: la.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

@description('Gives Package service identity ability to see its Key Vault instance.')
resource rsPackageKeyVault 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(miPackage.id, builtInReaderRole.id, kvPackage.id)
  scope: kvPackage
  properties: {
    principalId: miPackage.properties.principalId
    roleDefinitionId: builtInReaderRole.id
    principalType: 'ServicePrincipal'
  }
}

/*** OUTPUT ***/

output laWorkspace string = la.id
output acrId string = acr.id
output acrName string = acr.name
output deliveryKeyVaultUri string = kvDelivery.properties.vaultUri
output droneSchedulerKeyVaultUri string = kvDroneScheduler.properties.vaultUri
output deliveryRedisName string = redisDelivery.name
output deliveryCosmosDbName string = cosmosDbDelivery.name
output droneSchedulerCosmosDbName string = cosmosDbDroneScheduler.name
output packageMongoDbName string = mongoDbPackage.name
output ingestionQueueNamespace string = sbnIngestion.name
output ingestionQueueName string = sbnIngestion::ingestionQueue.name
output ingestionServiceAccessKeyName string = sbnIngestion::ingestionAccessKey.name
output workflowKeyVaultName string = kvWorkflow.name
output workflowServiceAccessKeyName string = sbnIngestion::workflowAccessKey.name
output deliveryKeyVaultName string = kvDelivery.name
output droneSchedulerKeyVaultName string = kvDroneScheduler.name
output ingestionKeyVaultName string = kvIngestion.name
output packageKeyVaultName string = kvPackage.name
output appInsightsName string = appInsights.name
