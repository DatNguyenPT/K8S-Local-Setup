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

# === LIST OF CONFIGMAPS ===
CONFIGMAPS=(
    "mysql/mysql-configmap.yaml"
    "postgres/postgres-configmap.yaml"
)

# === LIST OF PERSISTENT VOLUMES ===
PV_RESOURCES=(
    "mysql/mysql-pv.yaml"
    "postgres/postgres-pv.yaml"
)

# === LIST OF STATEFULSETS ===
STATEFULSETS=(
    "mysql/mysql-statefulset.yaml"
    "postgres/postgres-statefulset.yaml"
)

# === LIST OF SERVICES ===
SERVICES=(
    "mysql/service.yaml"
    "postgres/service.yaml"
)

# === CREATE CONFIGMAPS ===
for configmap in "${CONFIGMAPS[@]}"; do
    create_configmap "$(basename "$configmap" .yaml)" "$configmap"
done

# === APPLY PERSISTENT VOLUMES ===
for pv in "${PV_RESOURCES[@]}"; do
    apply_resource "PersistentVolume" "$pv"
done

# === APPLY STATEFULSETS ===
for statefulset in "${STATEFULSETS[@]}"; do
    apply_resource "StatefulSet" "$statefulset"
done

# === APPLY SERVICES ===
for service in "${SERVICES[@]}"; do
    apply_resource "Service" "$service"
done

echo "All resources applied successfully!"
