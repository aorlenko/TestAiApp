@description('Alternative Bicep template using SQLite with Azure Files for ultra-low cost')
targetScope = 'resourceGroup'

param appName string = 'todo-app'
param location string = resourceGroup().location
param environment string = 'dev'

var uniqueSuffix = uniqueString(resourceGroup().id)
var containerRegistryName = '${appName}acr${uniqueSuffix}'
var containerAppEnvName = '${appName}-env-${environment}'
var logAnalyticsWorkspaceName = '${appName}-logs-${uniqueSuffix}'
var storageAccountName = '${replace(appName, '-', '')}${uniqueSuffix}'
var fileShareName = 'todo-data'
var backendAppName = '${appName}-api-${environment}'
var frontendAppName = '${appName}-web-${environment}'

// Container Registry
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: containerRegistryName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
  }
}

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

// Container Apps Environment
resource containerAppEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: containerAppEnvName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
}

// Storage Account for SQLite database file
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS' // Locally redundant storage - cheapest option
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

// File Share for SQLite database
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-01-01' = {
  parent: storageAccount::fileServices
  name: fileShareName
  properties: {
    accessTier: 'TransactionOptimized'
    shareQuota: 1 // 1GB - more than enough for SQLite
  }
}

// Get storage account key for mounting
var storageAccountKey = storageAccount.listKeys().keys[0].value

// Backend Container App with Azure Files mount
resource backendApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: backendAppName
  location: location
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
        allowInsecure: false
        transport: 'auto'
      }
      registries: [
        {
          server: '${containerRegistry.name}.azurecr.io'
          identity: containerAppEnv.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'api'
          image: '${containerRegistry.properties.loginServer}/todo-api:latest'
          env: [
            {
              name: 'ASPNETCORE_ENVIRONMENT'
              value: 'Production'
            }
            {
              name: 'ConnectionStrings__TodoDb'
              value: 'Data Source=/data/todo.db'
            }
            {
              name: 'Frontend__Origin'
              value: '*' // Will be updated after frontend deployment
            }
          ]
          volumeMounts: [
            {
              volumeName: 'todo-data'
              mountPath: '/data'
            }
          ]
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }
        }
      ]
      volumes: [
        {
          name: 'todo-data'
          storageType: 'AzureFile'
          storageName: fileShare.name
          azureFile: {
            accountName: storageAccount.name
            accountKey: storageAccountKey
            shareName: fileShare.name
            accessMode: 'ReadWrite'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
    identity: {
      type: 'SystemAssigned'
    }
  }
}

// Frontend Container App
resource frontendApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: frontendAppName
  location: location
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 80
        allowInsecure: false
        transport: 'auto'
      }
      registries: [
        {
          server: '${containerRegistry.name}.azurecr.io'
          identity: containerAppEnv.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'frontend'
          image: '${containerRegistry.properties.loginServer}/todo-frontend:latest'
          env: [
            {
              name: 'API_URL'
              value: 'https://${backendApp.properties.configuration.ingress.fqdn}'
            }
          ]
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
    identity: {
      type: 'SystemAssigned'
    }
  }
}

output containerRegistryName string = containerRegistry.name
output containerRegistryLoginServer string = containerRegistry.properties.loginServer
output backendAppUrl string = 'https://${backendApp.properties.configuration.ingress.fqdn}'
output frontendAppUrl string = 'https://${frontendApp.properties.configuration.ingress.fqdn}'
output storageAccountName string = storageAccount.name
output fileShareName string = fileShare.name
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
