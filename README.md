# Trackr

Project management and support ticket platform built with SvelteKit and Supabase.

## Self-Hosted (Docker)

### Quick Start

```bash
git clone <repo-url> && cd Trackr
cp .env.example .env
# Edit .env — change passwords, JWT secrets, and keys for production
docker compose up --build -d
```

Once all services are healthy, open **http://localhost:3000**. On first launch you will be redirected to `/setup` where you create the platform owner account and root organization.

### Updating

```bash
git pull
docker compose up --build -d
```

New database migrations are applied automatically by the `db-migrations` service.

### Services

| Service | Port | Description |
|---------|------|-------------|
| App | 3000 | SvelteKit frontend |
| Kong | 8000 | Supabase API gateway |
| Studio | 8000 (via Kong) | Supabase dashboard (basic auth) |
| Inbucket | 9000 | Email testing UI |
| Postgres | 5432 | Database (via Supavisor) |

### Stopping

```bash
docker compose down        # stop containers, keep data
docker compose down -v     # stop and delete all data
```

## Local Development

For development, use the Supabase CLI instead of Docker Compose:

```bash
# Start Supabase locally (runs its own Docker containers)
supabase start

# Install app dependencies and start dev server
cd app
npm install
npm run dev
```

The dev server runs at **http://localhost:5173**. Supabase Studio is at **http://localhost:54323**.

### Environment Variables

Create `app/.env` for local development:

```
PUBLIC_SUPABASE_URL=http://localhost:54321
PUBLIC_SUPABASE_ANON_KEY=<from supabase start output>
SUPABASE_SERVICE_ROLE_KEY=<from supabase start output>
```

### Database Migrations

```bash
# Create a new migration
supabase migration new <name>

# Apply migrations
supabase db reset

# Pull remote schema changes
PGSSLMODE=disable supabase db pull --db-url postgresql://postgres:...@host:5432/postgres
```
