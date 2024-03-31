#!/bin/bash

if [ -n "${DATABASE_URL}" ]; then
    CONNECTION_URL="${DATABASE_URL}"
elif [ -n "${APP_DATABASE_URL}" ]; then
    CONNECTION_URL="${APP_DATABASE_URL}"
else
    echo "Neither DATABASE_URL nor APP_DATABASE_URL environment variable is set."
    exit 1
fi

# Optional directory from which to restore the backup file. The first argument is considered the backup file name.
BACKUP_FILE="${1:-}"

# Exit if no backup file is provided
if [ -z "$BACKUP_FILE" ]; then
    echo "Backup file must be provided as an argument."
    exit 2
fi

# Parsing the CONNECTION_URL
DB_USER=$(echo $CONNECTION_URL | sed -E 's/postgresql:\/\/([^:@]+).*$/\1/')
DB_HOST=$(echo $CONNECTION_URL | sed -E 's/.*@([^:/]+).*$/\1/')
DB_NAME=$(echo $CONNECTION_URL | sed -E 's/.*\/([^?]+).*$/\1/')

# Check for OVERRIDE_DB_NAME
if [ -n "${DB}" ]; then
    DB_NAME="${DB}"
fi

# Drop the existing database and recreate it
echo "Dropping existing database (if it exists) and creating a new one..."
dropdb --if-exists -h $DB_HOST -U $DB_USER $DB_NAME
createdb -h $DB_HOST -U postgres -O $DB_USER $DB_NAME

# Perform the restoration
# echo "Restoring database from $BACKUP_FILE..."
psql -h $DB_HOST -U $DB_USER -d $DB_NAME < "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "Restore successful"
else
    echo "Restore failed"
    exit 3
fi
