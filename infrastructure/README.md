# Azure Infrastructure as Code

This directory contains Bicep templates for deploying the Todo App to Azure.

## Prerequisites

- Azure CLI installed and configured
- Azure subscription with appropriate permissions
- GitHub repository with secrets configured (for CI/CD)

## Architecture

The infrastructure deploys:

- **Azure Container Registry (ACR)**: Stores Docker images
- **Azure Container Apps Environment**: Managed Kubernetes environment
- **Azure Container Apps**: 
  - Backend API (ASP.NET Core)
  - Frontend (React + Nginx)
- **Azure SQL Database**: Replaces SQLite for production
- **Log Analytics Workspace**: For monitoring and logging

## Manual Deployment

### 1. Set up Azure credentials

```bash
az login
az account set --subscription <your-subscription-id>
```

### 2. Create resource group

```bash
az group create --name todo-app-rg-dev --location westus2
```

### 3. Deploy infrastructure

```bash
cd infrastructure
az deployment group create \
  --resource-group todo-app-rg-dev \
  --template-file main.bicep \
  --parameters @parameters.dev.bicepparam \
  --parameters sqlAdminPassword="<your-secure-password>"
```

### 4. Build and push Docker images

```bash
# Get ACR name from deployment output
ACR_NAME=$(az acr list --resource-group todo-app-rg-dev --query "[0].name" -o tsv)

# Login to ACR
az acr login --name $ACR_NAME

# Build and push backend
cd ..
docker build -f backend/Todo.Api/Dockerfile -t $ACR_NAME.azurecr.io/todo-api:latest .
docker push $ACR_NAME.azurecr.io/todo-api:latest

# Build and push frontend
docker build -f frontend/Dockerfile -t $ACR_NAME.azurecr.io/todo-frontend:latest .
docker push $ACR_NAME.azurecr.io/todo-frontend:latest
```

### 5. Set SQL connection string secret

```bash
RG="todo-app-rg-dev"
SQL_SERVER=$(az sql server list --resource-group $RG --query "[0].name" -o tsv)
SQL_DB=$(az sql db list --resource-group $RG --server $SQL_SERVER --query "[0].name" -o tsv)
SQL_USER="todoadmin"
SQL_PASS="<your-password>"
CONN_STRING="Server=tcp:${SQL_SERVER}.database.windows.net,1433;Initial Catalog=${SQL_DB};Persist Security Info=False;User ID=${SQL_USER};Password=${SQL_PASS};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

az containerapp secret set \
  --name todo-app-api-dev \
  --resource-group $RG \
  --secrets sql-connection-string="$CONN_STRING"
```

### 6. Update Container Apps with frontend URL

```bash
RG="todo-app-rg-dev"
FRONTEND_URL=$(az containerapp show --name todo-app-web-dev --resource-group $RG --query "properties.configuration.ingress.fqdn" -o tsv)

az containerapp update \
  --name todo-app-api-dev \
  --resource-group $RG \
  --set-env-vars Frontend__Origin="https://${FRONTEND_URL}"
```

## CI/CD Deployment

The GitHub Actions workflow (`.github/workflows/deploy-azure.yml`) automatically:

1. Builds Docker images
2. Pushes to Azure Container Registry
3. Deploys/updates infrastructure
4. Configures secrets
5. Restarts Container Apps

### Required GitHub Secrets

Configure these secrets in your GitHub repository:

- `AZURE_CLIENT_ID`: Service Principal Client ID
- `AZURE_TENANT_ID`: Azure Tenant ID
- `AZURE_SUBSCRIPTION_ID`: Azure Subscription ID
- `AZURE_SQL_ADMIN_PASSWORD`: SQL Server admin password
- `AZURE_SQL_ADMIN_USERNAME`: SQL Server admin username (default: todoadmin)

### Create Service Principal

```bash
az ad sp create-for-rbac \
  --name "todo-app-github-actions" \
  --role contributor \
  --scopes /subscriptions/<subscription-id> \
  --sdk-auth
```

Copy the JSON output and add it to GitHub secrets, or extract individual values:
- `clientId` → `AZURE_CLIENT_ID`
- `tenantId` → `AZURE_TENANT_ID`
- `subscriptionId` → `AZURE_SUBSCRIPTION_ID`

## Environment Variables

### Backend Container App

- `ASPNETCORE_ENVIRONMENT`: Set to `Production`
- `ConnectionStrings__TodoDb`: SQL Server connection string (stored as secret)
- `Frontend__Origin`: Frontend URL for CORS

### Frontend Container App

- `API_URL`: Backend API URL for nginx proxy

## Monitoring

View logs and metrics in Azure Portal:
- Container Apps → Log stream
- Log Analytics Workspace → Logs

## Cost Optimization

### Current Setup (SQL Serverless)
- **Azure SQL Database Serverless**: Auto-pauses after 60 minutes of inactivity
  - When paused: ~$0.10-0.50/month (storage only)
  - When active: ~$5-10/month (compute + storage)
  - Perfect for dev/test or low-traffic apps

### Ultra-Low Cost Option (SQLite + Azure Files)
For even cheaper option, use `main-sqlite.bicep`:
- **Azure Files**: ~$0.06/GB/month (storage only)
- **SQLite**: No compute costs, just storage
- **Total**: ~$0.10-0.20/month for database storage
- Trade-off: Less concurrent access, but perfect for Todo apps

### Other Optimizations
- Container Apps scale to zero when not in use (no cost when idle)
- Log Analytics: Pay per GB ingested (can disable for dev)
- Container Registry Basic tier: Free tier available

## Troubleshooting

### Container App won't start

1. Check logs: `az containerapp logs show --name <app-name> --resource-group <rg-name>`
2. Verify image exists in ACR: `az acr repository list --name <acr-name>`
3. Check secrets are set: `az containerapp show --name <app-name> --resource-group <rg-name>`

### Database connection issues

1. Verify firewall rules allow Azure services
2. Check connection string format
3. Ensure SQL Server allows Azure services: `az sql server firewall-rule list --server <server-name> --resource-group <rg-name>`

### Frontend can't reach backend

1. Verify `API_URL` environment variable is set correctly
2. Check nginx logs in Container App
3. Verify backend ingress is configured correctly
