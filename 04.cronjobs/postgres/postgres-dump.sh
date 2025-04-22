#!/bin/bash

# === CONFIG ===
NAMESPACE="dbs"
LEASE_NAME="db-backup-lease"
HOLDER_ID="db-backup-$(hostname)-$$"
MAX_WAIT=30 
WAIT_INTERVAL=5

# Default upload flags
UPLOAD_TO_S3="N"
UPLOAD_TO_AZURE="N"

# === Parse flags ===
while [[ $# -gt 0 ]]; do
    case "$1" in
        --s3)
            UPLOAD_TO_S3="Y"
            shift
            ;;
        --azure)
            UPLOAD_TO_AZURE="Y"
            shift
            ;;
        --both)
            UPLOAD_TO_S3="Y"
            UPLOAD_TO_AZURE="Y"
            shift
            ;;
        --help)
            echo "Usage: $0 [--s3] [--azure] [--both]"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--s3] [--azure] [--both]"
            exit 1
            ;;
    esac
done

# Load secrets from ENV 
PG_USER=$POSTGRES_USER
PG_PASSWORD=$POSTGRES_PASSWORD
PG_HOST=$PG_HOST

AWS_ACCESS_KEY=$AWS_ACCESS_KEY
AWS_SECRET_KEY=$AWS_SECRET_KEY
AWS_BUCKET_NAME=$S3_BUCKET_NAME
AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION

AZURE_STORAGE_ACCOUNT=$AZURE_STORAGE_ACCOUNT
AZURE_STORAGE_KEY=$AZURE_STORAGE_KEY
AZURE_POSTGRES_CONTAINER_NAME=postgres

DATABASES=("test")
mkdir -p /backup
TIMESTAMP=$(date +%F-%H%M%S)
ARCHIVE_FILE="/backup/db-backup-${TIMESTAMP}.tar.gz"

# === LEASE WAIT + ACQUIRE ===
echo "Waiting for lease '${LEASE_NAME}' to be free..."
START_TIME=$(date +%s)
while true; do
    CURRENT_HOLDER=$(kubectl get lease "$LEASE_NAME" -n "$NAMESPACE" -o jsonpath='{.spec.holderIdentity}')
    if [[ -z "$CURRENT_HOLDER" || "$CURRENT_HOLDER" == "$HOLDER_ID" ]]; then
        echo "Acquiring lease with holder identity: $HOLDER_ID"
        kubectl patch lease "$LEASE_NAME" -n "$NAMESPACE" --type=merge -p \
            "{\"spec\": {\"holderIdentity\": \"${HOLDER_ID}\", \"leaseDurationSeconds\": 60}}"
        break
    fi
    NOW=$(date +%s)
    if (( NOW - START_TIME >= MAX_WAIT )); then
        echo "Lease is still held by '$CURRENT_HOLDER' after ${MAX_WAIT}s. Exiting."
        exit 1
    fi
    echo "Lease currently held by '$CURRENT_HOLDER'. Waiting..."
    sleep "$WAIT_INTERVAL"
done

# === Ensure /backup exists ===
mkdir -p /backup

# === Timestamp for filenames ===
TIMESTAMP=$(date +%F-%H%M%S)
PG_DUMP_FILE="/backup/postgresql-${TIMESTAMP}.sql"
ARCHIVE_FILE="/backup/db-backup-${TIMESTAMP}.tar.gz"

# === CLEANUP HANDLER ===
cleanup() {
    echo "Cleaning up..."
    rm -f "$PG_DUMP_FILE" "$ARCHIVE_FILE"
    echo "Releasing lease..."
    kubectl patch lease "$LEASE_NAME" -n "$NAMESPACE" --type=merge -p \
        "{\"spec\": {\"holderIdentity\": \"\"}}"
}
trap cleanup EXIT


# === Dump PostgreSQL ===
for DB_NAME in "${DATABASES[@]}"; do
    DUMP_FILE="/backup/postgres-${DB_NAME}-${TIMESTAMP}.sql"
    echo "Dumping Postgres database: $DB_NAME"
    PGPASSWORD=$PG_PASSWORD pg_dump -h $PG_HOST -U $PG_USER $PG_DB > $PG_DUMP_FILE
done
    
# === Compress ===
echo "Compressing..."
cd /backup
tar -czf postgres-backup-${TIMESTAMP}.tar.gz postgres-*.sql

# === Upload to S3 ===
if [[ "$UPLOAD_TO_S3" == "Y" ]]; then
    echo "Uploading to S3..."
    export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY
    export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_KEY
    export AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION
    aws s3 cp "db-backup-${TIMESTAMP}.tar.gz" s3://$AWS_BUCKET_NAME/
else
    echo "Skipping S3 upload."
fi

# === Upload to Azure ===
if [[ "$UPLOAD_TO_AZURE" == "Y" ]]; then
    echo "Uploading to Azure..."
    az storage container exists --account-name "$AZURE_STORAGE_ACCOUNT" --account-key "$AZURE_STORAGE_KEY" --name "$AZURE_MYSQL_CONTAINER_NAME" | grep -q false
    if [ $? -eq 0 ]; then
        echo "Container does not exist. Creating..."
        az storage container create --account-name "$AZURE_STORAGE_ACCOUNT" --account-key "$AZURE_STORAGE_KEY" --name "$AZURE_MYSQL_CONTAINER_NAME"
    fi

    az storage blob upload \
        --account-name "$AZURE_STORAGE_ACCOUNT" \
        --account-key "$AZURE_STORAGE_KEY" \
        --container-name "$AZURE_MYSQL_CONTAINER_NAME" \
        --name "db-backup-${TIMESTAMP}.tar.gz" \
        --file "db-backup-${TIMESTAMP}.tar.gz" \
        --overwrite true
else
    echo "Skipping Azure upload."
fi

echo "Final cleanup..."
rm -f /backup/*.sql /backup/*.tar.gz
