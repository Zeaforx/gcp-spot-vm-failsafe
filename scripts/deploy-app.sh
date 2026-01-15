#!/bin/bash
set -e

# script to deploy the application with dynamic project ID substitution

# Check if GOOGLE_PROJECT_ID is set
if [ -z "$GOOGLE_PROJECT_ID" ]; then
    echo "Error: GOOGLE_PROJECT_ID environment variable is not set."
    echo "Please export it using: export GOOGLE_PROJECT_ID=your-project-id"
    exit 1
fi

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "Error: kubectl is not installed."
    exit 1
fi

echo "Deploying to Project: $GOOGLE_PROJECT_ID"

# Verify we are connected to a cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: kubectl is not connected to a cluster."
    exit 1
fi

# Apply the manifests
echo "Applying Service..."
kubectl apply -f ../k8s/service.yaml

echo "Applying HPA..."
kubectl apply -f ../k8s/hpa.yaml

echo "Applying Deployment (substituting env vars)..."
# Use envsubst to substitute GOOGLE_PROJECT_ID in the template
envsubst < ../k8s/deployment.template.yaml | kubectl apply -f -

echo "Deployment complete!"
