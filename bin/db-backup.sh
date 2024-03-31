#!/bin/bash

# Function to print the usage of the script
print_usage() {
    echo "Usage: $0 [DIR]"
    echo "  DATABASE_URL must be passed in as an environment variable."
    echo "  DIR is the optional directory to save the backup file. Defaults to the current directory if not specified."
}

# Check if DATABASE_URL or APP_DATABASE_URL is set in the environment
if [ -n "${DATABASE_URL}" ]; then
    CONNECTION_URL="${DATABASE_URL}"
elif [ -n "${APP_DATABASE_URL}" ]; then
    CONNECTION_URL="${APP_DATABASE_URL}"
else
    echo "Neither DATABASE_URL nor APP_DATABASE_URL environment variable is set."
    exit 1
fi

# Optional directory to save the backup file
DIR="${1:-.}"

# Parse the DATABASE_URL
DB_USER=$(echo $CONNECTION_URL | sed -E 's/postgresql:\/\/([^:@]+).*$/\1/')
DB_HOST=$(echo $CONNECTION_URL | sed -E 's/.*@([^:/]+).*$/\1/')
DB_NAME=$(echo $CONNECTION_URL | sed -E 's/.*\/([^?]+).*$/\1/')

# Create DIR if it does not exist
mkdir -p "$DIR"

# Filename for backup
BACKUP_FILE="$DIR/${DB_NAME}_backup_$(date +%Y_%m_%d_%H%M%S).sql"


# Backup
# pg_dump -h $DB_HOST -U $DB_USER -d $DB_NAME > "$BACKUP_FILE"
pg_dump -h $DB_HOST -U $DB_USER $DB_NAME > "$BACKUP_FILE"

if [ $? -eq 0 ]; then
    echo "Backup successful: $BACKUP_FILE"
else
    echo "Backup failed"
    exit 2
fi
