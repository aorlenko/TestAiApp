# How the Deployed SPA Communicates with the Backend

## Architecture Overview

The deployed application uses a **reverse proxy pattern** where Nginx (running in the frontend container) proxies API requests to the backend.

## Communication Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    User's Browser                           │
│  (Accesses: https://todo-app-web-dev.azurecontainerapps.io) │
└────────────────────────┬────────────────────────────────────┘
                         │ HTTPS
                         ▼
┌─────────────────────────────────────────────────────────────┐
│         Frontend Container App (Azure Container Apps)        │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Nginx (Port 80)                                      │ │
│  │  - Serves React SPA static files                      │ │
│  │  - Proxies /api/* requests to backend                 │ │
│  │  - Uses API_URL env var:                              │ │
│  │    https://todo-app-api-dev.azurecontainerapps.io     │ │
│  └────────────────────────────────────────────────────────┘ │
└────────────────────────┬────────────────────────────────────┘
                         │ HTTPS (proxied)
                         │ /api/todos → backend
                         ▼
┌─────────────────────────────────────────────────────────────┐
│          Backend Container App (Azure Container Apps)        │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  ASP.NET Core API (Port 8080)                         │ │
│  │  - Handles /api/todos endpoints                        │ │
│  │  - Connects to Azure SQL Database                     │ │
│  └────────────────────────────────────────────────────────┘ │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
                 ┌───────────────┐
                 │ Azure SQL DB  │
                 └───────────────┘
```

## Step-by-Step Request Flow

### 1. User Opens the App
- Browser navigates to: `https://todo-app-web-dev.azurecontainerapps.io`
- Azure Container Apps routes to the Frontend Container App
- Nginx serves the React SPA (`index.html` and static assets)

### 2. Frontend Makes API Call
- React app calls: `fetch('/api/todos')`
- This is a **relative URL**, so the browser sends request to the same origin
- Request goes to: `https://todo-app-web-dev.azurecontainerapps.io/api/todos`

### 3. Nginx Proxy Intercepts
- Nginx receives the `/api/todos` request
- Matches the `/api/` location block in `nginx.conf.template`
- Reads `API_URL` environment variable: `https://todo-app-api-dev.azurecontainerapps.io`
- Proxies the request to: `https://todo-app-api-dev.azurecontainerapps.io/api/todos`

### 4. Backend Processes Request
- Azure Container Apps routes to the Backend Container App
- ASP.NET Core API handles the request
- Queries Azure SQL Database
- Returns JSON response

### 5. Response Returns to Frontend
- Backend → Nginx → Browser → React app
- React app updates the UI with the data

## Configuration Details

### Frontend Container App

**Environment Variable:**
```yaml
API_URL: https://todo-app-api-dev.azurecontainerapps.io
```

**Nginx Configuration** (`nginx.conf.template`):
```nginx
location /api/ {
    proxy_pass ${API_URL}/api/;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;
}
```

**Ingress Configuration:**
- External: `true` (publicly accessible)
- Target Port: `80`
- HTTPS: Enabled (automatic TLS certificate)

### Backend Container App

**Ingress Configuration:**
- External: `true` (publicly accessible)
- Target Port: `8080`
- HTTPS: Enabled (automatic TLS certificate)
- CORS: Configured to allow requests from frontend origin

**CORS Configuration:**
```csharp
Frontend__Origin: https://todo-app-web-dev.azurecontainerapps.io
```

## Why This Architecture?

### ✅ Benefits

1. **Same-Origin Policy**: Frontend and API appear to be on the same domain
   - No CORS issues
   - Cookies work seamlessly
   - Simpler security model

2. **Single Entry Point**: Users only need to know one URL
   - Frontend URL is the only public endpoint
   - Backend can be kept more secure (though currently public)

3. **Flexibility**: Easy to change backend URL
   - Just update `API_URL` environment variable
   - No code changes needed

4. **HTTPS Everywhere**: All communication is encrypted
   - Browser → Frontend: HTTPS
   - Frontend → Backend: HTTPS (proxied)
   - Backend → Database: Encrypted connection

### 🔒 Security Considerations

**Current Setup:**
- Both frontend and backend have **external ingress** (publicly accessible)
- Backend can be accessed directly: `https://todo-app-api-dev.azurecontainerapps.io/api/todos`

**For Production (Optional Enhancement):**
- Set backend ingress to `internal: true` (only accessible within Container Apps Environment)
- Only frontend can reach backend via internal networking
- More secure, but requires internal networking configuration

## URLs After Deployment

After deployment, you'll get URLs like:

- **Frontend**: `https://todo-app-web-dev.azurecontainerapps.io`
- **Backend**: `https://todo-app-api-dev.azurecontainerapps.io`

The frontend automatically uses the backend URL via the `API_URL` environment variable.

## Testing the Communication

### Test Frontend (via Nginx proxy):
```bash
curl https://todo-app-web-dev.azurecontainerapps.io/api/todos
```

### Test Backend Directly:
```bash
curl https://todo-app-api-dev.azurecontainerapps.io/api/todos
```

Both should return the same data, but the frontend route goes through Nginx proxy.

## Troubleshooting

### Frontend can't reach backend

1. **Check API_URL environment variable:**
   ```bash
   az containerapp show --name todo-app-web-dev --resource-group todo-app-rg-dev \
     --query "properties.template.containers[0].env"
   ```

2. **Check backend is accessible:**
   ```bash
   curl https://todo-app-api-dev.azurecontainerapps.io/health
   ```

3. **Check Nginx logs:**
   ```bash
   az containerapp logs show --name todo-app-web-dev --resource-group todo-app-rg-dev
   ```

4. **Verify CORS configuration:**
   - Backend must allow frontend origin
   - Check `Frontend__Origin` environment variable in backend

### CORS Errors

If you see CORS errors in browser console:
- Verify `Frontend__Origin` in backend matches frontend URL exactly
- Check backend CORS configuration allows the frontend origin
- Ensure backend ingress is configured correctly
