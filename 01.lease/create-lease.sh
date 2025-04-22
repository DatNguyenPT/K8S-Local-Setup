#!/bin/bash

NAMESPACE="db-backup"

FILES=("lease.yaml" "lease-cronjob.yaml")

echo "Applying Kubernetes resources to namespace '$NAMESPACE'..."

for file in "${FILES[@]}"; do
    if [[ -f "$file" ]]; then
        echo "Applying $file..."
        kubectl apply -n "$NAMESPACE" -f "$file"
    else
        echo "File not found: $file"
        exit 1
    fi
done

echo "All resources applied successfully."
