#!/bin/bash

# === SETTINGS ===
NAMESPACE="db-backup"

# Function to apply Kubernetes resources
apply_resource() {
    local resource_type=$1
    local manifest=$2
    echo "Applying ${resource_type}: ${manifest}..."
    if kubectl apply -n "$NAMESPACE" -f "$manifest"; then
        echo "Successfully applied: $manifest"
    else
        echo "Failed to apply: $manifest"
        exit 1
    fi
}

# Function to create a ConfigMap
create_configmap() {
    local name=$1
    local file=$2
    echo "Creating ConfigMap ${name} from ${file}..."
    if kubectl create configmap "$name" --from-file="$file" -n "$NAMESPACE"; then
        echo "Successfully created ConfigMap: $name"
    else
        echo "Failed to create ConfigMap: $name"
        exit 1
    fi
}

# === CONFIGMAPS ===
CONFIGMAPS=(
    "postgres-backup-script=postgresql/postgres-dump.sh"
)

# === CRONJOBS ===
CRONJOBS=(
    "postgresql/cronjob.yaml"
)

# === CREATE CONFIGMAPS ===
for configmap in "${CONFIGMAPS[@]}"; do
    IFS="=" read -r name file <<< "$configmap"
    create_configmap "$name" "$file"
done

# === APPLY CRONJOBS ===
for cronjob in "${CRONJOBS[@]}"; do
    apply_resource "CronJob" "$cronjob"
done

echo "All resources applied successfully!"
