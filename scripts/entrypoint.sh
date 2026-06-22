#!/bin/sh
set -e

if [ "$PRISMA_DB_PULL_ON_START" = "true" ]; then
  echo "Re-introspecting database schema..."
  bunx --bun prisma db pull --force
fi

echo "Generating Prisma Client..."
bunx --bun prisma generate

echo "Starting Prisma Studio on 0.0.0.0:5555..."
exec bunx --bun prisma studio --port 5555 --hostname 0.0.0.0 --browser none
