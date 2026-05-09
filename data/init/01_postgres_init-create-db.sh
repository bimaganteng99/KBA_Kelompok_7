psql -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "postgres" <<'EOSQL'
SELECT format('CREATE DATABASE odoo OWNER odoo;')
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'odoo')
\gexec
EOSQL
