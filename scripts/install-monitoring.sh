#!/bin/bash

# Script to install Prometheus and Grafana monitoring stack for the Hybrid Kubernetes Cost Optimization project
# This enables collection of Infrastructure metrics (CPU, Memory, Pod Status, Node Status)

set -e

echo "========================================="
echo "Installing Monitoring Stack"
echo "========================================="

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo "Error: helm is not installed. Please install helm first."
    echo "Visit: https://helm.sh/docs/intro/install/"
    exit 1
fi

# Check if kubectl is configured
if ! kubectl cluster-info &> /dev/null; then
    echo "Error: kubectl is not configured or cluster is not accessible."
    echo "Please ensure you have run: gcloud container clusters get-credentials <cluster-name>"
    exit 1
fi

# Add Prometheus Community Helm Repository
echo "Adding Prometheus Community Helm repo..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create monitoring namespace
echo "Creating monitoring namespace..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Install kube-prometheus-stack
echo "Installing kube-prometheus-stack..."
helm upgrade --install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values ../configs/monitoring-values.yaml \
  --wait

echo ""
echo "========================================="
echo "Monitoring Stack Installed Successfully!"
echo "========================================="
echo ""
echo "Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=grafana -n monitoring --timeout=300s

echo ""
echo "To access Grafana:"
echo "  1. Run: kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80"
echo "  2. Open browser: http://localhost:3000"
echo "  3. Login with username: admin, password: admin"
echo ""
echo "To access Prometheus:"
echo "  1. Run: kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090"
echo "  2. Open browser: http://localhost:9090"
echo ""
