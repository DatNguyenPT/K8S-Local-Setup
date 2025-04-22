#!/bin/bash

# === SETTINGS ===
NAMESPACE="db-backup"
LOG_FILE="install.log"

# Function to apply Kubernetes resources
apply_resource() {
    local resource_script=$1
    echo "Running ${resource_script}..." | tee -a "$LOG_FILE"
    chmod +x "$resource_script"
    
    # Check if the script exists and is executable
    if [ ! -x "$resource_script" ]; then
        echo "Error: $resource_script is not executable or does not exist." | tee -a "$LOG_FILE"
        exit 1
    fi

    # Apply the script
    if bash "$resource_script"; then
        echo "Successfully applied: $resource_script" | tee -a "$LOG_FILE"
    else
        echo "Failed to apply: $resource_script" | tee -a "$LOG_FILE"
        exit 1
    fi
}

# === VERIFY IF NAMESPACE EXISTS ===
kubectl get namespace "$NAMESPACE" &>/dev/null
if [ $? -ne 0 ]; then
    echo "Namespace '$NAMESPACE' does not exist. Please create it first." | tee -a "$LOG_FILE"
    exit 1
fi

# === APPLY RESOURCES ===
# 00.sa/lease
apply_resource "00.sa/lease/create-sa.sh"

# 01.lease
apply_resource "01.lease/create-lease.sh"

# 02.test-db
apply_resource "02.test-db/create-test-db.sh"

# 03.secrets
apply_resource "03.secrets/create-secrets.sh"

# 04.cronjobs
apply_resource "04.cronjobs/create-cronjob-mysql.sh"
apply_resource "04.cronjobs/create-cronjob-postgres.sh"

echo "All resources applied successfully!" | tee -a "$LOG_FILE"
