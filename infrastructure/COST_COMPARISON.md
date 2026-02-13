# Database Cost Comparison

## Option 1: Azure SQL Database Serverless (Current - Recommended)

**Cost**: ~$0.10-10/month depending on usage

### Pros:
- ✅ Auto-pauses after inactivity (60 min)
- ✅ Auto-scales compute when active
- ✅ Full SQL Server features
- ✅ Easy to upgrade later
- ✅ No code changes needed

### Cons:
- ⚠️ Slight delay on first request after pause (~10-30 seconds)
- ⚠️ Minimum 0.5 vCore when active

### Pricing:
- **Paused**: ~$0.10-0.50/month (storage only, 2GB)
- **Active (low traffic)**: ~$5-10/month
- **Active (medium traffic)**: ~$15-30/month

**Best for**: Dev/test environments, low-to-medium traffic production apps

---

## Option 2: SQLite + Azure Files (Ultra-Low Cost)

**Cost**: ~$0.10-0.20/month

### Pros:
- ✅ Extremely cheap (~$0.06/GB/month storage)
- ✅ No compute costs
- ✅ No pause delays
- ✅ Already supported in your codebase

### Cons:
- ⚠️ Limited concurrent writes (SQLite limitation)
- ⚠️ No built-in backup (need to implement)
- ⚠️ File locking can be an issue with multiple replicas

### Pricing:
- **Storage**: ~$0.06/GB/month (1GB share = ~$0.06/month)
- **Compute**: $0 (uses Container App compute)
- **Total**: ~$0.10-0.20/month

**Best for**: Personal projects, very low traffic, single-user apps

---

## Option 3: Azure SQL Database Basic (Original)

**Cost**: ~$5/month (always running)

### Pros:
- ✅ Always available (no pause delays)
- ✅ Predictable cost
- ✅ Full SQL Server features

### Cons:
- ⚠️ Always running (costs even when idle)
- ⚠️ Fixed capacity

**Best for**: Production apps with consistent traffic

---

## Recommendation

### For Development/Testing:
**Use SQL Serverless** (current setup) - Auto-pauses, very cheap when idle

### For Production (Low Traffic):
**Use SQL Serverless** - Best balance of cost and features

### For Production (Very Low Traffic / Personal):
**Use SQLite + Azure Files** - Ultra-cheap, good enough for Todo apps

### For Production (High Traffic):
**Upgrade to Standard tier** - Better performance, predictable costs

---

## How to Switch

### Switch to SQLite + Azure Files:

1. Deploy using `main-sqlite.bicep`:
   ```bash
   az deployment group create \
     --resource-group todo-app-rg-dev \
     --template-file infrastructure/main-sqlite.bicep \
     --parameters @infrastructure/parameters.dev.bicepparam
   ```

2. No code changes needed - your app already supports SQLite!

3. Update GitHub Actions workflow to use `main-sqlite.bicep` instead of `main.bicep`

### Switch Back to SQL Serverless:

Just use `main.bicep` (current default)

---

## Monthly Cost Estimate (Dev Environment)

| Component | SQL Serverless | SQLite + Files |
|-----------|---------------|----------------|
| SQL Database | $0.10-5 | $0 |
| Azure Files | $0 | $0.06 |
| Container Apps | $0-5 | $0-5 |
| Container Registry | $0 (free tier) | $0 (free tier) |
| Log Analytics | $0-2 | $0-2 |
| **Total** | **$0.10-12** | **$0.06-7** |

*Container Apps cost $0 when scaled to zero (idle)*

---

## Cost Savings Tips

1. **Use SQL Serverless** - Auto-pauses save ~90% cost when idle
2. **Scale Container Apps to zero** - No cost when not in use
3. **Disable Log Analytics** for dev (optional)
4. **Use Azure Files** for SQLite if ultra-low cost is priority
5. **Delete resources** when not testing to avoid any charges
