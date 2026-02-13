targetScope = 'resourceGroup'

param appName string = 'todo-app'
param location string = 'eastus'
param environment string = 'dev'
param sqlAdminUsername string = 'todoadmin'
@secure()
param sqlAdminPassword string
@description('Auto-pause delay in minutes (minimum 60). Set to -1 to disable auto-pause.')
param sqlAutoPauseDelay int = 60

var uniqueSuffix = uniqueString(resourceGroup().id)
var containerRegistryName = '${replace(appName, '-', '')}acr${uniqueSuffix}'
var containerAppEnvName = '${appName}-env-${environment}'
var logAnalyticsWorkspaceName = '${appName}-logs-${uniqueSuffix}'
var sqlServerName = '${appName}-sql-${uniqueSuffix}'
var sqlDatabaseName = '${appName}-db'
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
  identity: {
    type: 'SystemAssigned'
  }
}

// SQL Server
resource sqlServer 'Microsoft.Sql/servers@2023-05-01-preview' = {
  name: sqlServerName
  location: location
  properties: {
    administratorLogin: sqlAdminUsername
    administratorLoginPassword: sqlAdminPassword
    version: '12.0'
    minimalTlsVersion: '1.2'
  }
}

// SQL Database - Using Serverless for cost optimization (auto-pauses when inactive)
resource sqlDatabase 'Microsoft.Sql/servers/databases@2023-05-01-preview' = {
  parent: sqlServer
  name: sqlDatabaseName
  location: location
  sku: {
    name: 'GP_S_Gen5_1'
    tier: 'GeneralPurpose'
    family: 'Gen5'
    capacity: 1
  }
  properties: {
    collation: 'SQL_Latin1_General_CP1_CI_AS'
    maxSizeBytes: 2147483648 // 2GB
    requestedBackupStorageRedundancy: 'Local'
    autoPauseDelay: sqlAutoPauseDelay >= 60 ? sqlAutoPauseDelay : (sqlAutoPauseDelay == -1 ? -1 : 60)
    // Note: minCapacity removed due to Bicep type validation issue (expects int but Azure supports decimal)
    // Serverless will use default minimum capacity
  }
}

// Firewall rule to allow Azure services
resource sqlFirewallRule 'Microsoft.Sql/servers/firewallRules@2023-05-01-preview' = {
  parent: sqlServer
  name: 'AllowAzureServices'
  properties: {
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
}

// Backend Container App
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
          server: '${containerRegistry.properties.loginServer}'
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
              value: 'PLACEHOLDER' // Will be updated after deployment via workflow
            }
            {
              name: 'Frontend__Origin'
              value: '*' // Will be updated after frontend deployment
            }
          ]
          resources: {
            cpu: json('0.5')
            memory: '1.0Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }
  identity: {
    type: 'SystemAssigned'
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
          server: '${containerRegistry.properties.loginServer}'
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
  }
  identity: {
    type: 'SystemAssigned'
  }
}

// Grant Container Apps Environment identity AcrPull role on Container Registry
resource containerRegistryRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistry
  name: guid(containerAppEnv.id, containerRegistry.id, 'AcrPull')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe0d1daa5e') // AcrPull
    principalId: containerAppEnv.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// SQL Connection String Secret (will be set manually or via pipeline)
// Note: In production, use Azure Key Vault for secrets management

output containerRegistryName string = containerRegistry.name
output containerRegistryLoginServer string = containerRegistry.properties.loginServer
output backendAppUrl string = 'https://${backendApp.properties.configuration.ingress.fqdn}'
output frontendAppUrl string = 'https://${frontendApp.properties.configuration.ingress.fqdn}'
output sqlServerName string = sqlServer.name
output sqlDatabaseName string = sqlDatabase.name
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
