#!/bin/bash
set -e

# This script runs when postgres initializes for the first time
# It creates the keycloak database and user

echo "====================================="
echo "PostgreSQL Database Initialization"
echo "====================================="

# Set defaults
KEYCLOAK_DB_NAME="${KEYCLOAK_DB:-keycloak}"
KEYCLOAK_DB_USERNAME="${KEYCLOAK_DB_USER:-keycloak}"
KEYCLOAK_DB_PASS="${KEYCLOAK_DB_PASSWORD:-keycloak_default}"

echo "Main database: $POSTGRES_DB"
echo "Keycloak database: $KEYCLOAK_DB_NAME"
echo "Keycloak user: $KEYCLOAK_DB_USERNAME"

# Create keycloak user if it doesn't exist
echo "Creating Keycloak database and user..."

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Create keycloak user if not exists
    DO \$\$
    BEGIN
        IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$KEYCLOAK_DB_USERNAME') THEN
            CREATE USER $KEYCLOAK_DB_USERNAME WITH PASSWORD '$KEYCLOAK_DB_PASS';
            RAISE NOTICE 'Created user: $KEYCLOAK_DB_USERNAME';
        ELSE
            RAISE NOTICE 'User already exists: $KEYCLOAK_DB_USERNAME';
        END IF;
    END
    \$\$;

    -- Create keycloak database if not exists
    SELECT 'CREATE DATABASE $KEYCLOAK_DB_NAME OWNER $KEYCLOAK_DB_USERNAME'
    WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$KEYCLOAK_DB_NAME')\gexec

    -- Grant privileges
    GRANT ALL PRIVILEGES ON DATABASE $KEYCLOAK_DB_NAME TO $KEYCLOAK_DB_USERNAME;
EOSQL

if [ $? -eq 0 ]; then
    echo "✓ Keycloak database and user created successfully"
else
    echo "✗ Failed to create Keycloak database and user"
    exit 1
fi

# Verify the database was created
DB_COUNT=$(psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -tAc "SELECT COUNT(*) FROM pg_database WHERE datname='$KEYCLOAK_DB_NAME'")

if [ "$DB_COUNT" = "1" ]; then
    echo "✓ Verified database '$KEYCLOAK_DB_NAME' exists"
else
    echo "✗ Database '$KEYCLOAK_DB_NAME' was not created"
    exit 1
fi

echo "====================================="
echo "PostgreSQL initialization complete"
echo "====================================="
