#!/bin/bash

# === CONFIG ===
NAMESPACE="db-backup"
OUT_DIR="./output-secrets"
mkdir -p "$OUT_DIR"

# === Helper Function ===
create_secret() {
  local name=$1
  local file=$2
  local output_file="${OUT_DIR}/${name}.yaml"

  if [[ ! -f "$file" ]]; then
    echo "❌ Config file '$file' not found. Skipping secret '$name'."
    return 1
  fi

  echo "Creating secret '$name' from '$file'..."
  kubectl create secret generic "$name" \
    --from-env-file="$file" \
    --namespace="$NAMESPACE" \
    --dry-run=client -o yaml > "$output_file"

  if [[ $? -eq 0 ]]; then
    echo "Saved: $output_file"
  else
    echo "Failed to generate secret YAML for '$name'."
  fi
}

# === Create All Secrets ===
create_secret "mysql-secret" "mysql-secrets.conf"
create_secret "postgres-secret" "postgres-secrets.conf"
create_secret "aws-secret" "aws-secrets.conf"
create_secret "blob-secret" "blob-secrets.conf"

echo "Secret generation complete. YAML files are in '$OUT_DIR'"
