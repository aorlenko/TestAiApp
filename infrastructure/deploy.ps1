# PowerShell script for initial Azure infrastructure deployment
param(
    [Parameter(Mandatory=$true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory=$true)]
    [string]$Environment,
    
    [Parameter(Mandatory=$true)]
    [string]$SqlAdminPassword,
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "westus2",
    
    [Parameter(Mandatory=$false)]
    [string]$SqlAdminUsername = "todoadmin"
)

Write-Host "Deploying Todo App infrastructure to Azure..." -ForegroundColor Green

# Check if Azure CLI is installed
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error "Azure CLI is not installed. Please install it from https://aka.ms/installazurecliwindows"
    exit 1
}

# Check if logged in
$account = az account show 2>$null
if (-not $account) {
    Write-Host "Please login to Azure..." -ForegroundColor Yellow
    az login
}

# Create resource group
Write-Host "Creating resource group: $ResourceGroupName" -ForegroundColor Cyan
az group create --name $ResourceGroupName --location $Location | Out-Null

# Deploy infrastructure
Write-Host "Deploying Bicep template..." -ForegroundColor Cyan
$deployment = az deployment group create `
    --resource-group $ResourceGroupName `
    --template-file infrastructure/main.bicep `
    --parameters @infrastructure/parameters.$Environment.bicepparam `
    --parameters sqlAdminPassword=$SqlAdminPassword `
    --parameters sqlAdminUsername=$SqlAdminUsername `
    --output json | ConvertFrom-Json

if ($LASTEXITCODE -ne 0) {
    Write-Error "Deployment failed!"
    exit 1
}

Write-Host "Infrastructure deployed successfully!" -ForegroundColor Green

# Get outputs
$acrName = $deployment.properties.outputs.containerRegistryName.value
$backendUrl = $deployment.properties.outputs.backendAppUrl.value
$frontendUrl = $deployment.properties.outputs.frontendAppUrl.value

Write-Host "`nDeployment outputs:" -ForegroundColor Yellow
Write-Host "  Container Registry: $acrName" -ForegroundColor White
Write-Host "  Backend URL: $backendUrl" -ForegroundColor White
Write-Host "  Frontend URL: $frontendUrl" -ForegroundColor White

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Build and push Docker images:" -ForegroundColor White
Write-Host "   az acr login --name $acrName" -ForegroundColor Gray
Write-Host "   docker build -f backend/Todo.Api/Dockerfile -t $acrName.azurecr.io/todo-api:latest ." -ForegroundColor Gray
Write-Host "   docker push $acrName.azurecr.io/todo-api:latest" -ForegroundColor Gray
Write-Host "   docker build -f frontend/Dockerfile -t $acrName.azurecr.io/todo-frontend:latest ." -ForegroundColor Gray
Write-Host "   docker push $acrName.azurecr.io/todo-frontend:latest" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Set SQL connection string secret:" -ForegroundColor White
Write-Host "   See infrastructure/README.md for details" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Configure GitHub Actions secrets for CI/CD" -ForegroundColor White
