# Todo Hackathon App

Local-first full-stack Todo application:
- `frontend`: React + TypeScript SPA
- `backend/Todo.Api`: ASP.NET Web API + SQLite
- `docker-compose.yml`: local infrastructure as code
- `.github/workflows/ci.yml`: CI pipeline for backend/frontend checks

## Features

- Create, edit, complete/reopen, delete tasks
- Filter by all/active/completed
- Persistent storage with SQLite
- Clean API contracts with validation

## Run Locally (Dev Mode)

### 1) Start the backend API

```powershell
dotnet run --project .\backend\Todo.Api\Todo.Api.csproj
```

API runs on `http://localhost:5059`.

### 2) Start the frontend SPA

```powershell
cd .\frontend
npm install
npm run dev
```

Frontend runs on `http://localhost:5173`.

The Vite dev server proxies `/api/*` to the backend.

## Run with Docker (Single Command)

```powershell
docker compose up --build
```

- Frontend: `http://localhost:5173`
- API: `http://localhost:5059/api/todos`

## Build Checks

```powershell
dotnet build .\backend\Todo.Api\Todo.Api.csproj
cd .\frontend
npm run lint
npm run build
```
