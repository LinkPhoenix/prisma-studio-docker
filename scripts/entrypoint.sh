#!/bin/sh
set -e

if [ -z "$DATABASE_URL" ]; then
  export DATABASE_URL="$(bun /app/scripts/resolve-database-url.ts)"
fi

if [ "$PRISMA_DB_PULL_ON_START" = "true" ]; then
  echo "Re-introspecting database schema..."
  bunx --bun prisma db pull --force
fi

echo "Generating Prisma Client..."
bunx --bun prisma generate

echo "Starting Prisma Studio on port 5555..."
exec bunx --bun prisma studio --port 5555 --browser none
