using '../infrastructure/main.bicep'

param appName = 'todo-app'
param environment = 'dev'
param sqlAdminUsername = 'todoadmin'
param sqlAutoPauseDelay = 60 // Auto-pause after 60 minutes of inactivity (minimum)
// sqlAdminPassword should be provided via Azure CLI or pipeline secrets
