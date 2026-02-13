# GitHub Actions Workflows

This directory contains CI/CD workflows for the Todo App.

## Workflows

### `ci.yml`
Runs on every push and pull request:
- Builds and tests backend (.NET)
- Lints and builds frontend (React/TypeScript)

### `deploy-azure.yml`
Deploys to Azure on:
- Push to `main` branch → Production environment
- Push to `develop` branch → Development environment
- Manual trigger → Choose environment

## Required Secrets

Configure these in GitHub repository settings → **Secrets and variables → Actions → Repository secrets** (click "New repository secret"):

| Secret Name | Description | Example |
|------------|-------------|---------|
| `AZURE_CLIENT_ID` | Service Principal Client ID | `12345678-1234-1234-1234-123456789abc` |
| `AZURE_TENANT_ID` | Azure Tenant ID | `87654321-4321-4321-4321-cba987654321` |
| `AZURE_SUBSCRIPTION_ID` | Azure Subscription ID | `11111111-2222-3333-4444-555555555555` |
| `AZURE_SQL_ADMIN_PASSWORD` | SQL Server admin password | Strong password |
| `AZURE_SQL_ADMIN_USERNAME` | SQL Server admin username | `todoadmin` |

**Important**: Use **Repository secrets** (not Environment secrets). The workflow uses the same Azure credentials for both dev and prod environments. If you need different credentials per environment, you can:
1. Use Environment secrets with GitHub Environments feature (requires workflow changes)
2. Or use different secret names like `AZURE_CLIENT_ID_DEV` and `AZURE_CLIENT_ID_PROD`

## Creating Service Principal

```bash
az ad sp create-for-rbac \
  --name "todo-app-github-actions" \
  --role contributor \
  --scopes /subscriptions/<subscription-id> \
  --sdk-auth
```

Copy the output JSON and extract:
- `clientId` → `AZURE_CLIENT_ID`
- `tenantId` → `AZURE_TENANT_ID`
- `subscriptionId` → `AZURE_SUBSCRIPTION_ID`

## Workflow Steps

1. **Build and Push**: Builds Docker images and pushes to Azure Container Registry
2. **Deploy Infrastructure**: Deploys/updates Azure resources using Bicep
3. **Configure Secrets**: Sets SQL connection string in Container App
4. **Update CORS**: Configures frontend origin in backend CORS policy
5. **Restart Apps**: Restarts Container Apps to pick up new images

## Manual Deployment

You can manually trigger the deployment workflow:
1. Go to Actions tab
2. Select "Deploy to Azure" workflow
3. Click "Run workflow"
4. Choose environment (dev/prod)
5. Click "Run workflow" button
