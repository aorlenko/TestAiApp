# Setting Up Azure Secrets for GitHub Actions

## Why Secrets Are Required

The deployment workflow needs Azure credentials to:
1. Authenticate with Azure
2. Deploy infrastructure (Container Apps, SQL Database, etc.)
3. Push Docker images to Azure Container Registry
4. Configure Azure resources

**Without these secrets, the workflow will fail** with a clear error message.

## Required Secrets

You need to configure these **Repository secrets** in GitHub:

| Secret Name | Description | How to Get It |
|------------|-------------|---------------|
| `AZURE_CLIENT_ID` | Service Principal Client ID | From Azure Service Principal |
| `AZURE_CLIENT_SECRET` | Service Principal Client Secret | From Azure Service Principal (when creating) |
| `AZURE_TENANT_ID` | Azure Tenant ID | From Azure Service Principal |
| `AZURE_SUBSCRIPTION_ID` | Azure Subscription ID | From Azure Portal or CLI |
| `AZURE_SQL_ADMIN_PASSWORD` | SQL Server admin password | Create a strong password |
| `AZURE_SQL_ADMIN_USERNAME` | SQL Server admin username | Default: `todoadmin` |

## Step-by-Step Setup

### 1. Create Azure Service Principal

Run this command in Azure CLI:

```bash
az ad sp create-for-rbac \
  --name "todo-app-github-actions" \
  --role contributor \
  --scopes /subscriptions/<your-subscription-id> \
  --sdk-auth
```

**Output example:**
```json
{
  "clientId": "12345678-1234-1234-1234-123456789abc",
  "clientSecret": "your-secret-here",
  "subscriptionId": "11111111-2222-3333-4444-555555555555",
  "tenantId": "87654321-4321-4321-4321-cba987654321",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```

### 2. Get Your Subscription ID

If you don't have it:

```bash
az account show --query id -o tsv
```

Or find it in Azure Portal → Subscriptions

### 3. Add Secrets to GitHub

1. Go to your repository on GitHub
2. Click **Settings** (top menu)
3. Click **Secrets and variables** → **Actions**
4. Click **Repository secrets** tab
5. Click **New repository secret**
6. Add each secret:

   **Secret 1: `AZURE_CLIENT_ID`**
   - Value: `clientId` from step 1 output
   - Click **Add secret**

   **Secret 2: `AZURE_CLIENT_SECRET`** ⚠️ **IMPORTANT**
   - Value: `clientSecret` from step 1 output
   - **Note**: This is only shown once when creating the service principal!
   - Click **Add secret**

   **Secret 3: `AZURE_TENANT_ID`**
   - Value: `tenantId` from step 1 output
   - Click **Add secret**

   **Secret 4: `AZURE_SUBSCRIPTION_ID`**
   - Value: `subscriptionId` from step 1 output
   - Click **Add secret**

   **Secret 5: `AZURE_SQL_ADMIN_PASSWORD`**
   - Value: Create a strong password (e.g., `MySecurePassword123!`)
   - Click **Add secret**

   **Secret 6: `AZURE_SQL_ADMIN_USERNAME`** (Optional)
   - Value: `todoadmin` (or your preferred username)
   - Click **Add secret**

### 4. Verify Secrets Are Set

After adding all secrets, you should see them listed under **Repository secrets**.

## What Happens Without Secrets?

The workflow will:
1. ✅ Run successfully until it reaches the "Login to Azure" step
2. ❌ Fail with a clear error message:
   ```
   Error: Azure secrets are not configured. 
   Please configure AZURE_CLIENT_ID, AZURE_TENANT_ID, and AZURE_SUBSCRIPTION_ID 
   in repository secrets.
   ```

## Security Notes

- ✅ Secrets are encrypted and never exposed in logs
- ✅ Only workflows in this repository can access these secrets
- ✅ Secrets are masked in workflow logs (shown as `***`)
- ⚠️ Never commit secrets to your repository
- ⚠️ Rotate secrets periodically for security

## Troubleshooting

### "Authentication failed"
- Verify `AZURE_CLIENT_ID`, `AZURE_CLIENT_SECRET`, and `AZURE_TENANT_ID` are correct
- **Important**: If you lost the client secret, you need to create a new one:
  ```bash
  az ad sp credential reset --id <client-id> --append
  ```
- Check service principal still exists: `az ad sp show --id <client-id>`
- Verify service principal has Contributor role

### "Subscription not found"
- Verify `AZURE_SUBSCRIPTION_ID` is correct
- Check you have access to the subscription: `az account show`

### "Insufficient permissions"
- Service principal needs Contributor role on subscription
- Re-run the service principal creation command with correct scope

## Next Steps

After configuring secrets:
1. The workflow will automatically authenticate with Azure
2. It can deploy infrastructure and push Docker images
3. You can monitor progress in the Actions tab
