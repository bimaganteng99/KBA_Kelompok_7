
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "postgres" <<-EOSQL
    -- Cek dan buat database odoo
    SELECT 'CREATE DATABASE odoo OWNER odoo' 
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'odoo')\gexec

    -- Cek dan buat database metabase_db
    SELECT 'CREATE DATABASE metabase_db OWNER odoo' 
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'metabase_db')\gexec
EOSQL

