#!/bin/bash

# Configuration
PROJECT_ID=$(gcloud config get-value project)
ZONE="us-central1-a" # Should match Terraform
CLUSTER_NAME="hybrid-cost-optimized-cluster"

echo "Retrieving Spot Node Instances..."
# Get list of nodes in the spot pool
SPOT_NODES=$(kubectl get nodes -l cloud.google.com/gke-spot=true -o jsonpath='{.items[*].metadata.name}')

if [ -z "$SPOT_NODES" ]; then
    echo "Error: No Spot nodes found. Ensure the cluster is running and nodes are provisioned."
    exit 1
fi

# Pick the first spot node
TARGET_NODE=$(echo $SPOT_NODES | awk '{print $1}')
echo "Targeting Spot Node for Preemption Simulation: $TARGET_NODE"

# Simulate Maintenance Event (Preemption)
echo "Triggering maintenance event..."
gcloud compute instances simulate-maintenance-event $TARGET_NODE --zone=$ZONE --project=$PROJECT_ID

echo "Maintenance event triggered. Monitor the pods using: kubectl get pods -w"
