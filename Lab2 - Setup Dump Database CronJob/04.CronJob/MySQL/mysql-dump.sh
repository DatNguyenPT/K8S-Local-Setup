#!/bin/bash

# === CONFIG ===
NAMESPACE="dbs"
LEASE_NAME="db-backup-lease"
HOLDER_ID="db-backup-$(hostname)-$$"
MAX_WAIT=30 
WAIT_INTERVAL=5

# Load secrets from ENV 
MYSQL_USER=root
MYSQL_PASSWORD=$MYSQL_ROOT_PASSWORD

AWS_ACCESS_KEY=$AWS_ACCESS_KEY
AWS_SECRET_KEY=$AWS_SECRET_KEYs
AWS_BUCKET_NAME=$S3_BUCKET_NAME

AZURE_STORAGE_ACCOUNT=$AZURE_STORAGE_ACCOUNT
AZURE_STORAGE_KEY=$AZURE_STORAGE_KEY
AZURE_MYSQL_CONTAINER_NAME=mysql
AZURE_POSTGRES_CONTAINER_NAME=postgres

db=test

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
MYSQL_DUMP_FILE="/backup/mysql-${TIMESTAMP}.sql"
ARCHIVE_FILE="/backup/db-backup-${TIMESTAMP}.tar.gz"

# === CLEANUP HANDLER ===
cleanup() {
    echo "Cleaning up..."
    rm -f "$MYSQL_DUMP_FILE" "$ARCHIVE_FILE"
    echo "Releasing lease..."
    kubectl patch lease "$LEASE_NAME" -n "$NAMESPACE" --type=merge -p \
        "{\"spec\": {\"holderIdentity\": \"\"}}"
}
trap cleanup EXIT

# === Dump MySQL ===
MYSQL_HOST=mysql.dbs.svc.cluster.local
MYSQL_DB=$db
echo "Dumping MySQL..."
mysqldump -h $MYSQL_HOST -u $MYSQL_USER -p"$MYSQL_PASSWORD" $MYSQL_DB > $MYSQL_DUMP_FILE

# === Compress ===
echo "Compressing..."
cd /backup
tar -czf mysql-backup-${TIMESTAMP}.tar.gz mysql-*.sql 

# === Upload To S3 ===
echo "Uploading to S3..."

export AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY
export AWS_SECRET_ACCESS_KEY=$AWS_SECRET_KEY
export AWS_DEFAULT_REGION=us-east-1

aws s3 cp mysql-backup-${TIMESTAMP}.tar.gz s3://$AWS_BUCKET_NAME/

# === Create Containers ===
az storage container exists --account-name $AZURE_STORAGE_ACCOUNT --account-key $AZURE_STORAGE_KEY --name $AZURE_MYSQL_CONTAINER_NAME
if [ $? -ne 0 ]; then
    echo "MySQL container does not exist. Creating container..."
    az storage container create --account-name $AZURE_STORAGE_ACCOUNT --account-key $AZURE_STORAGE_KEY --name $AZURE_MYSQL_CONTAINER_NAME
fi

# === Upload To Azure ===
echo "Uploading to Azure..."

export AZURE_STORAGE_ACCOUNT=$AZURE_STORAGE_ACCOUNT
export AZURE_STORAGE_KEY=$AZURE_STORAGE_KEY

az storage blob upload --account-name $AZURE_STORAGE_ACCOUNT \
    --account-key $AZURE_STORAGE_KEY \
    --container-name $AZURE_MYSQL_CONTAINER_NAME \
    --name mysql-backup-${TIMESTAMP}.tar.gz \
    --file mysql-backup-${TIMESTAMP}.tar.gz \
    --overwrite true

# === Clean Up ===
echo "Cleaning up..."
rm -f *.sql *.tar.gz