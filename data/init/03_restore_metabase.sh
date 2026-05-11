#!/usr/bin/env bash
set -e

DB_EXISTS=$(psql -U "$POSTGRES_USER" -d "postgres" -tAc "SELECT 1 FROM pg_database WHERE datname='metabase_db'")

if [ "$DB_EXISTS" != "1" ]; then
    echo "Membuat database metabase_db..."
    psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "postgres" -c "CREATE DATABASE metabase_db;"
else
    echo "Database metabase_db sudah ada, melewati pembuatan."
fi

echo "Memulai restore metadata Metabase..."
if [ -f /dumps/metabase_new.sql ]; then
    psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "metabase_db" -f /dumps/metabase_new.sql
    echo "Restore Metabase selesai!"
else
    echo "File /dumps/metabase_new.sql tidak ditemukan, skipping."
fi