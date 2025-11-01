#!/bin/bash
set -e

# This script runs when postgres initializes for the first time
# It creates the keycloak database and user

echo "Creating Keycloak database and user..."

# Create keycloak user if it doesn't exist
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create keycloak user if not exists
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${KEYCLOAK_DB_USER:-keycloak}') THEN
            CREATE USER ${KEYCLOAK_DB_USER:-keycloak} WITH PASSWORD '${KEYCLOAK_DB_PASSWORD}';
        END IF;
    END
    \$\$;

    -- Create keycloak database if not exists
    SELECT 'CREATE DATABASE ${KEYCLOAK_DB:-keycloak} OWNER ${KEYCLOAK_DB_USER:-keycloak}'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${KEYCLOAK_DB:-keycloak}')\gexec

    -- Grant privileges
    GRANT ALL PRIVILEGES ON DATABASE ${KEYCLOAK_DB:-keycloak} TO ${KEYCLOAK_DB_USER:-keycloak};
EOSQL

echo "Keycloak database and user created successfully"
