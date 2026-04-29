#!/usr/bin/env bash
set -e

psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "postgres" -c "CREATE DATABASE metabase_db;"

echo "Memulai restore metadata Metabase..."
if [ -f /dumps/metabase.sql ]; then
    # Sesuaikan -d dengan nama database tempat Metabase menyimpan datanya
    psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "metabase_db" -f /dumps/metabase.sql
    echo "Restore Metabase selesai!"
else
    echo "File dumps/metabase.sql tidak ditemukan, skipping."
fi