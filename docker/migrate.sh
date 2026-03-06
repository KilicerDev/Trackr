#!/bin/sh
set -e

MIGRATIONS_DIR="/migrations"
DB_URL="${DATABASE_URL}"

if [ -z "$DB_URL" ]; then
  echo "ERROR: DATABASE_URL is not set"
  exit 1
fi

echo "Waiting for database to accept connections..."
until psql "$DB_URL" -c "SELECT 1" > /dev/null 2>&1; do
  sleep 1
done

echo "Creating migration tracking table if needed..."
psql "$DB_URL" -c "
  CREATE TABLE IF NOT EXISTS public._trackr_migrations (
    filename TEXT PRIMARY KEY,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
  );
"

applied=0
skipped=0

for f in "$MIGRATIONS_DIR"/*.sql; do
  [ -f "$f" ] || continue
  basename=$(basename "$f")

  already=$(psql "$DB_URL" -tAc "SELECT 1 FROM public._trackr_migrations WHERE filename = '$basename' LIMIT 1")

  if [ "$already" = "1" ]; then
    skipped=$((skipped + 1))
    continue
  fi

  echo "Applying $basename ..."
  psql "$DB_URL" -v ON_ERROR_STOP=1 -f "$f"

  psql "$DB_URL" -c "INSERT INTO public._trackr_migrations (filename) VALUES ('$basename')"
  applied=$((applied + 1))
done

if [ "$applied" -gt 0 ]; then
  echo "Notifying PostgREST to reload schema cache..."
  psql "$DB_URL" -c "NOTIFY pgrst, 'reload schema'"
fi

echo "Migrations complete: $applied applied, $skipped already applied."
