#!/bin/bash
set -e

# Wait for database to be ready
echo "Waiting for database..."
until PGPASSWORD=$DATABASE_PASSWORD psql -h "$DATABASE_HOST" -U "$DATABASE_USERNAME" -d "$DATABASE_NAME" -c "SELECT 1" > /dev/null 2>&1; do
  sleep 2
done
echo "Database is ready!"

# Run migrations
echo "Running database migrations..."
bundle exec rails db:migrate

# Remove server pid if exists
rm -f tmp/pids/server.pid

echo "Starting Decidim..."
exec bundle exec rails server -b 0.0.0.0 -p 3000
