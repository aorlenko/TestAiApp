# Azure Deployment Guide

This guide walks you through deploying the Todo App to Azure using Infrastructure as Code (IaC) and CI/CD pipelines.

## Quick Start

### Prerequisites

1. **Azure Account**: Active Azure subscription
2. **Azure CLI**: [Install Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli)
3. **Docker**: For building container images locally (optional - CI/CD handles this)
4. **GitHub Account**: For CI/CD pipelines

### Option 1: Automated Deployment via GitHub Actions (Recommended)

1. **Fork/Clone the repository**

2. **Create Azure Service Principal for GitHub Actions**:
   ```bash
   az ad sp create-for-rbac --name "todo-app-github-actions" --role contributor --scopes /subscriptions/<your-subscription-id> --sdk-auth
   ```

3. **Configure GitHub Secrets**:
   Go to your repository → Settings → Secrets and variables → Actions → **Repository secrets** (not Environment secrets), and add:
   - `AZURE_CLIENT_ID`: From service principal output
   - `AZURE_TENANT_ID`: From service principal output
   - `AZURE_SUBSCRIPTION_ID`: Your Azure subscription ID
   - `AZURE_SQL_ADMIN_PASSWORD`: Strong password for SQL Server
   - `AZURE_SQL_ADMIN_USERNAME`: SQL admin username (default: `todoadmin`)

   **Note**: Use **Repository secrets** (not Environment secrets) since the workflow doesn't use GitHub Environments feature. Repository secrets are available to all workflows and simpler to manage.

4. **Push to trigger deployment**:
   - Push to `main` branch → deploys to `prod` environment
   - Push to `develop` branch → deploys to `dev` environment
   - Or use "Run workflow" button to manually trigger

### Option 2: Manual Deployment

#### Step 1: Deploy Infrastructure

Using PowerShell:
```powershell
cd test_task
.\infrastructure\deploy.ps1 `
  -ResourceGroupName "todo-app-rg-dev" `
  -Environment "dev" `
  -SqlAdminPassword "YourSecurePassword123!"
```

Or using Azure CLI:
```bash
# Create resource group
az group create --name todo-app-rg-dev --location westus2

# Deploy infrastructure
cd test_task/infrastructure
az deployment group create \
  --resource-group todo-app-rg-dev \
  --template-file main.bicep \
  --parameters @parameters.dev.bicepparam \
  --parameters sqlAdminPassword="YourSecurePassword123!"
```

#### Step 2: Build and Push Docker Images

```bash
# Get ACR name from deployment output
ACR_NAME=$(az acr list --resource-group todo-app-rg-dev --query "[0].name" -o tsv)

# Login to ACR
az acr login --name $ACR_NAME

# Build and push backend
cd test_task
docker build -f backend/Todo.Api/Dockerfile -t $ACR_NAME.azurecr.io/todo-api:latest .
docker push $ACR_NAME.azurecr.io/todo-api:latest

# Build and push frontend
docker build -f frontend/Dockerfile -t $ACR_NAME.azurecr.io/todo-frontend:latest .
docker push $ACR_NAME.azurecr.io/todo-frontend:latest
```

#### Step 3: Configure SQL Connection String

```bash
RG="todo-app-rg-dev"
SQL_SERVER=$(az sql server list --resource-group $RG --query "[0].name" -o tsv)
SQL_DB=$(az sql db list --resource-group $RG --server $SQL_SERVER --query "[0].name" -o tsv)
SQL_USER="todoadmin"
SQL_PASS="YourSecurePassword123!"
CONN_STRING="Server=tcp:${SQL_SERVER}.database.windows.net,1433;Initial Catalog=${SQL_DB};Persist Security Info=False;User ID=${SQL_USER};Password=${SQL_PASS};MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

az containerapp secret set \
  --name todo-app-api-dev \
  --resource-group $RG \
  --secrets sql-connection-string="$CONN_STRING"
```

#### Step 4: Update Frontend Origin in Backend CORS

```bash
RG="todo-app-rg-dev"
FRONTEND_URL=$(az containerapp show --name todo-app-web-dev --resource-group $RG --query "properties.configuration.ingress.fqdn" -o tsv)

az containerapp update \
  --name todo-app-api-dev \
  --resource-group $RG \
  --set-env-vars Frontend__Origin="https://${FRONTEND_URL}"
```

#### Step 5: Verify Deployment

```bash
# Get URLs
RG="todo-app-rg-dev"
BACKEND_URL=$(az containerapp show --name todo-app-api-dev --resource-group $RG --query "properties.configuration.ingress.fqdn" -o tsv)
FRONTEND_URL=$(az containerapp show --name todo-app-web-dev --resource-group $RG --query "properties.configuration.ingress.fqdn" -o tsv)

echo "Backend: https://${BACKEND_URL}"
echo "Frontend: https://${FRONTEND_URL}"

# Test health endpoint
curl https://${BACKEND_URL}/health
```

## Architecture

The deployment creates:

- **Azure Container Registry**: Stores Docker images
- **Azure Container Apps Environment**: Managed Kubernetes environment
- **Backend Container App**: ASP.NET Core API
- **Frontend Container App**: React SPA with Nginx
- **Azure SQL Database**: Production database (replaces SQLite)
- **Log Analytics Workspace**: Centralized logging

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/deploy-azure.yml`) automatically:

1. ✅ Builds Docker images for backend and frontend
2. ✅ Pushes images to Azure Container Registry
3. ✅ Deploys/updates infrastructure using Bicep
4. ✅ Configures SQL connection string secret
5. ✅ Updates CORS settings
6. ✅ Restarts Container Apps with new images

### Pipeline Triggers

- **Push to `main`**: Deploys to `prod` environment
- **Push to `develop`**: Deploys to `dev` environment
- **Manual trigger**: Choose environment via workflow_dispatch

## Environment Configuration

### Development Environment

- Resource Group: `todo-app-rg-dev`
- Container Apps: `todo-app-api-dev`, `todo-app-web-dev`
- SQL Database: Basic tier

### Production Environment

- Resource Group: `todo-app-rg-prod`
- Container Apps: `todo-app-api-prod`, `todo-app-web-prod`
- SQL Database: Basic tier (consider upgrading for production)

## Monitoring

### View Logs

```bash
# Backend logs
az containerapp logs show \
  --name todo-app-api-dev \
  --resource-group todo-app-rg-dev \
  --follow

# Frontend logs
az containerapp logs show \
  --name todo-app-web-dev \
  --resource-group todo-app-rg-dev \
  --follow
```

### Azure Portal

- Navigate to Container Apps → Your app → Log stream
- Or use Log Analytics Workspace for advanced queries

## Troubleshooting

### Container App won't start

1. Check logs: `az containerapp logs show --name <app-name> --resource-group <rg-name>`
2. Verify image exists: `az acr repository list --name <acr-name>`
3. Check secrets: `az containerapp show --name <app-name> --resource-group <rg-name>`

### Database connection errors

1. Verify firewall allows Azure services
2. Check connection string format
3. Ensure SQL Server is accessible: `az sql server firewall-rule list --server <server-name> --resource-group <rg-name>`

### Frontend can't reach backend

1. Verify `API_URL` environment variable in frontend Container App
2. Check nginx configuration
3. Verify backend ingress is external and HTTPS enabled

### GitHub Actions deployment fails

1. Verify all secrets are configured correctly
2. Check service principal has Contributor role
3. Review workflow logs for specific error messages

## Cost Optimization

### Database Options

**Option 1: SQL Serverless (Current - Recommended)**
- ✅ Auto-pauses after 60 minutes of inactivity
- ✅ **When paused**: ~$0.10-0.50/month (storage only)
- ✅ **When active**: ~$5-10/month (compute + storage)
- ✅ Perfect for dev/test and low-traffic production

**Option 2: SQLite + Azure Files (Ultra-Low Cost)**
- ✅ **Total cost**: ~$0.10-0.20/month (storage only)
- ✅ No compute costs
- ✅ Use `main-sqlite.bicep` template instead
- ⚠️ Limited concurrent writes (fine for Todo apps)

### Other Optimizations

- **Container Apps**: Scale to zero when not in use (no cost when idle)
- **Container Registry**: Basic tier included in free tier
- **Log Analytics**: Pay per GB ingested (can disable for dev)

### Estimated Monthly Costs

| Environment | SQL Serverless | SQLite + Files |
|------------|---------------|----------------|
| **Dev (idle)** | ~$0.10-1/month | ~$0.10-0.20/month |
| **Dev (active)** | ~$5-10/month | ~$0.10-0.20/month |
| **Prod (low traffic)** | ~$5-15/month | ~$0.10-0.20/month |

See `infrastructure/COST_COMPARISON.md` for detailed cost breakdown.

## Security Best Practices

1. ✅ Use strong SQL admin passwords (stored in GitHub secrets)
2. ✅ Enable HTTPS only (configured in Container Apps)
3. ✅ Use managed identities where possible (future enhancement)
4. ✅ Enable Azure Defender for SQL (optional, additional cost)
5. ✅ Restrict SQL firewall rules to specific IPs in production
6. ✅ Use Azure Key Vault for secrets in production (future enhancement)

## Next Steps

- [ ] Set up custom domains
- [ ] Configure Azure Key Vault for secrets
- [ ] Enable Application Insights for APM
- [ ] Set up alerting and monitoring
- [ ] Configure backup for SQL Database
- [ ] Implement blue-green deployments
- [ ] Add staging environment
