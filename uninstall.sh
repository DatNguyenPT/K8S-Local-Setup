#!/bin/bash

# === SETTINGS ===
NAMESPACE="db-backup"
LOG_FILE="uninstall.log"

# Function to delete Kubernetes resources
delete_resource() {
    local resource_script=$1
    echo "Running ${resource_script} to delete resources..." | tee -a "$LOG_FILE"
    if bash "$resource_script"; then
        echo "Successfully deleted: $resource_script" | tee -a "$LOG_FILE"
    else
        echo "Failed to delete: $resource_script" | tee -a "$LOG_FILE"
        exit 1
    fi
}

# === VERIFY IF NAMESPACE EXISTS ===
kubectl get namespace "$NAMESPACE" &>/dev/null
if [ $? -ne 0 ]; then
    echo "Namespace '$NAMESPACE' does not exist. Skipping deletion process." | tee -a "$LOG_FILE"
    exit 1
fi

# === DELETE RESOURCES ===

# 00.sa/lease
delete_resource "00.sa/lease/create-sa.sh"

# 01.lease
delete_resource "01.lease/create-lease.sh"

# 02.test-db
delete_resource "02.test-db/create-test-db.sh"

# 03.secrets
delete_resource "03.secrets/create-secrets.sh"

# 04.cronjobs
delete_resource "04.cronjobs/create-cronjob-mysql.sh"
delete_resource "04.cronjobs/create-cronjob-postgres.sh"

echo "All resources deleted successfully!" | tee -a "$LOG_FILE"
