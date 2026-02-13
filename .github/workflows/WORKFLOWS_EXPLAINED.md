# GitHub Actions Workflows Explained

## Overview

This repository has **2 workflows** located in `.github/workflows/`:

1. **`ci.yml`** - Continuous Integration (build & test)
2. **`deploy-azure.yml`** - Continuous Deployment (deploy to Azure)

## Workflow Comparison

| Feature | `ci.yml` | `deploy-azure.yml` |
|---------|----------|-------------------|
| **Purpose** | Build & validate code | Deploy to Azure |
| **Triggers** | Every push/PR | Push to `main`/`develop` or manual |
| **What it does** | Builds & lints code | Builds, pushes Docker images, deploys infrastructure |
| **Runs on** | All branches | `main`, `develop` branches only |
| **Azure access** | ❌ No | ✅ Yes (requires secrets) |
| **Duration** | ~2-5 minutes | ~5-15 minutes |

## 1. CI Workflow (`ci.yml`)

### Location
```
.github/workflows/ci.yml
```

### Purpose
**Continuous Integration** - Validates code quality and ensures code builds successfully.

### Triggers
- ✅ **Every push** to any branch
- ✅ **Every pull request**

### What it does
1. **Backend Job**:
   - Restores .NET dependencies
   - Builds the ASP.NET Core API
   - Validates compilation

2. **Frontend Job**:
   - Installs npm dependencies
   - Lints TypeScript/React code
   - Builds the React SPA
   - Validates build succeeds

### Key Features
- ✅ Fast feedback (runs on every commit)
- ✅ No Azure credentials needed
- ✅ Prevents broken code from being merged
- ✅ Runs in parallel (backend + frontend simultaneously)

### Example Output
```
✓ Backend builds successfully
✓ Frontend lints pass
✓ Frontend builds successfully
```

---

## 2. Deploy to Azure Workflow (`deploy-azure.yml`)

### Location
```
.github/workflows/deploy-azure.yml
```

### Purpose
**Continuous Deployment** - Builds Docker images and deploys the application to Azure.

### Triggers
- ✅ **Push to `main` branch** → Deploys to `prod` environment
- ✅ **Push to `develop` branch** → Deploys to `dev` environment
- ✅ **Manual trigger** (`workflow_dispatch`) → Choose environment

### What it does

#### Job 1: Build and Push
1. Builds backend Docker image
2. Builds frontend Docker image
3. Pushes images to Azure Container Registry
4. Tags images with commit SHA and `latest`

#### Job 2: Deploy Infrastructure
1. Deploys Azure infrastructure using Bicep templates
2. Creates/updates:
   - Container Registry
   - Container Apps Environment
   - Backend Container App
   - Frontend Container App
   - SQL Database
   - Log Analytics Workspace
3. Configures SQL connection string secret
4. Updates CORS settings
5. Restarts Container Apps with new images

### Key Features
- ✅ Full deployment automation
- ✅ Infrastructure as Code (Bicep)
- ✅ Environment-aware (dev/prod)
- ✅ Requires Azure credentials (GitHub secrets)

### Example Output
```
✓ Images built and pushed to ACR
✓ Infrastructure deployed
✓ Backend URL: https://todo-app-api-dev.azurecontainerapps.io
✓ Frontend URL: https://todo-app-web-dev.azurecontainerapps.io
```

---

## Workflow Relationship

```
┌─────────────────────────────────────────────────────────┐
│                    Developer pushes code                 │
└────────────────┬──────────────────────────────────────────┘
                 │
                 ▼
        ┌─────────────────┐
        │   ci.yml runs   │  ← Runs on EVERY push/PR
        │  (build & test) │
        └────────┬────────┘
                 │
                 ▼
         ┌───────────────┐
         │ Build passes? │
         └───────┬───────┘
                 │
        ┌────────┴────────┐
        │                 │
        ▼                 ▼
    ❌ Fail          ✅ Pass
    (stop)           │
                     │
                     ▼
        ┌──────────────────────┐
        │ deploy-azure.yml runs │  ← Only on main/develop
        │   (deploy to Azure)   │
        └──────────────────────┘
```

## Typical Workflow

1. **Developer pushes to feature branch**
   - ✅ `ci.yml` runs → Validates code builds
   - ❌ `deploy-azure.yml` does NOT run

2. **Developer opens Pull Request**
   - ✅ `ci.yml` runs → Ensures PR is valid
   - ❌ `deploy-azure.yml` does NOT run

3. **PR merged to `develop` branch**
   - ✅ `ci.yml` runs → Final validation
   - ✅ `deploy-azure.yml` runs → Deploys to **dev** environment

4. **Code promoted to `main` branch**
   - ✅ `ci.yml` runs → Final validation
   - ✅ `deploy-azure.yml` runs → Deploys to **prod** environment

## File Structure

```
.github/
└── workflows/
    ├── ci.yml              ← CI workflow (build & test)
    ├── deploy-azure.yml    ← CD workflow (deploy to Azure)
    └── README.md           ← Workflow documentation
```

## When to Use Each

### Use `ci.yml` when:
- ✅ You want to validate code before merging
- ✅ You want fast feedback on build errors
- ✅ You're working on a feature branch
- ✅ You want to ensure code quality

### Use `deploy-azure.yml` when:
- ✅ You want to deploy to Azure
- ✅ Code is ready for dev/prod environments
- ✅ You've merged to `main` or `develop`
- ✅ You want to manually trigger a deployment

## Manual Deployment

You can manually trigger `deploy-azure.yml`:

1. Go to **Actions** tab in GitHub
2. Select **"Deploy to Azure"** workflow
3. Click **"Run workflow"** button
4. Choose environment (`dev` or `prod`)
5. Click **"Run workflow"**

This is useful for:
- Re-deploying after infrastructure changes
- Deploying hotfixes
- Testing deployment process

## Troubleshooting

### CI fails but code works locally
- Check Node.js/.NET versions match
- Verify all dependencies are committed
- Check for platform-specific issues

### Deploy workflow fails
- Verify Azure secrets are configured
- Check Azure service principal permissions
- Review deployment logs for specific errors
- Ensure resource group exists (or has permissions to create)

### Want to skip CI on a commit?
Add `[skip ci]` to commit message:
```
git commit -m "Update docs [skip ci]"
```

### Want to skip deployment?
Deployment only runs on `main` and `develop` branches, so pushing to other branches won't trigger it.
