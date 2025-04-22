#!/bin/bash

MANIFESTS=("lease-sa.yaml" "role.yaml" "role-binding.yaml")
NAMESPACE="db-backup"

echo "Applying Kubernetes RBAC resources for Lease locking..."

for manifest in "${MANIFESTS[@]}"; do
    if [[ -f "$manifest" ]]; then
        echo "Applying ${manifest}..."
        if kubectl apply -n "$NAMESPACE" -f "$manifest"; then
            echo "Successfully applied: $manifest"
        else
            echo "Failed to apply: $manifest"
            exit 1
        fi
    else
        echo "Manifest file not found: $manifest"
        exit 1
    fi
done

echo "All resources applied successfully."
