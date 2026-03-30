# Trackr
 
Project management and support ticket platform built with SvelteKit and Supabase.

## Getting Started

### Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (v20.10+) and [Docker Compose](https://docs.docker.com/compose/) (v2+)
- [Git](https://git-scm.com/)

### Setup

```bash
git clone https://github.com/KilicerDev/Trackr.git && cd Trackr
cp .env.example .env
```

Edit `.env` and adjust the values to match your setup.

### Start

```bash
docker compose up -d
```

The initial startup may take several minutes while images are pulled and built.

### Access

Once all containers are running, open **[http://localhost](http://localhost)** in your browser. On first launch you'll be redirected to `/setup` where you create the platform owner account and root organization.

### Next Steps

- Create your first project from the Dashboard
- Invite team members via **Settings > Team**
- See the [full documentation](https://trackr.dev/docs) for production deployment, semantic search, and advanced configuration


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

The dev server runs at **[http://localhost:5173](http://localhost:5173)**. Supabase Studio is at **[http://localhost:54323](http://localhost:54323)**.

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

## License

[AGPL-3.0](LICENSE)
