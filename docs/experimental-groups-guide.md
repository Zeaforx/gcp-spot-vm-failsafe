# Running the Three Experimental Groups

This guide explains how to run each of the three experimental groups defined in the methodology and track their costs separately.

## Overview

According to the proposal, you need to run **three separate experiments**:

| Group                  | Configuration             | Purpose                         |
| ---------------------- | ------------------------- | ------------------------------- |
| **Control Group A**    | On-Demand only            | Baseline for stability and cost |
| **Control Group B**    | Spot only                 | Quantify "cost of failure"      |
| **Experimental Group** | Hybrid (Spot + On-Demand) | Test the proposed solution      |

## Cost Tracking Strategy

Each cluster will be labeled with `experiment-group` to separate costs in GCP Billing:

- `experiment-group=control-a`
- `experiment-group=control-b`
- `experiment-group=experimental`

---

## Experiment 1: Control Group A (On-Demand Only)

### Purpose

Establish the **baseline** for:

- Cost (highest, but most stable)
- Reliability (should be 100%)
- Performance (baseline latency)

### Terraform Configuration

Edit `terraform/terraform.tfvars`:

```hcl
project_id       = "your-project-id"
region           = "us-central1"
cluster_name     = "control-a-cluster"
experiment_group = "control-a"
```

### Modify `terraform/main.tf`

**Comment out or delete the Spot node pool** (lines 36-74):

```hcl
# Node Pool 2: Spot (Primary Workload)
# resource "google_container_node_pool" "spot_nodes" {
#   ... (comment out entire block)
# }
```

**OR** create a separate `main-control-a.tf`:

```hcl
# Only keep the on-demand pool, remove spot pool
resource "google_container_node_pool" "on_demand_nodes" {
  name       = "on-demand-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name

  autoscaling {
    min_node_count = 1
    max_node_count = 10
  }

  initial_node_count = 1

  node_config {
    machine_type = "e2-medium"
    disk_size_gb = 50
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = {
      "node-type"        = "on-demand"
      "experiment-group" = var.experiment_group
    }
  }
}
```

### Deploy & Run

```bash
cd terraform
terraform init
terraform apply

cd ../k8s
# Remove tolerations and affinity from deployment.yaml (use plain deployment)
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f hpa.yaml

cd ../scripts
bash run-experiments.sh
```

### Expected Results

- **Error Rate**: 0%
- **Cost**: Highest (baseline)
- **Failover Time**: N/A (no preemption)

---

## Experiment 2: Control Group B (Spot Only)

### Purpose

Quantify the **"cost of failure"**:

- How much does Spot save? (target: ~70%)
- What is the error rate without fallback?
- How long is downtime during preemption?

### Terraform Configuration

Edit `terraform/terraform.tfvars`:

```hcl
project_id       = "your-project-id"
region           = "us-central1"
cluster_name     = "control-b-cluster"
experiment_group = "control-b"
```

### Modify `terraform/main.tf`

**Comment out the On-Demand node pool** (lines 15-34):

```hcl
# Node Pool 1: On-Demand (Fallback / System)
# resource "google_container_node_pool" "on_demand_nodes" {
#   ... (comment out entire block)
# }
```

**Remove the taint from Spot pool** (so pods can schedule):

```hcl
resource "google_container_node_pool" "spot_nodes" {
  # ... existing config ...

  node_config {
    # ... existing config ...

    # REMOVE the taint block:
    # taint {
    #   key    = "node-type"
    #   value  = "spot"
    #   effect = "NO_SCHEDULE"
    # }
  }
}
```

### Modify `k8s/deployment.yaml`

**Remove tolerations and affinity** (pods should schedule on Spot without preference):

```yaml
spec:
  containers:
    - name: app
      # ... existing config ...

  # REMOVE these sections:
  # affinity:
  #   nodeAffinity: ...
  # tolerations: ...
```

### Deploy & Run

```bash
cd terraform
terraform apply

cd ../k8s
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f hpa.yaml

cd ../scripts
bash run-experiments.sh
```

### Expected Results

- **Error Rate**: >0% (pods will fail during preemption)
- **Cost**: Lowest (~70% savings)
- **Failover Time**: High (pods stuck in Pending until new Spot nodes provision)

---

## Experiment 3: Experimental Group (Hybrid)

### Purpose

Validate the **proposed solution**:

- Achieve cost savings close to Spot-only
- Maintain reliability close to On-Demand
- Demonstrate fast failover (<10s)

### Terraform Configuration

Edit `terraform/terraform.tfvars`:

```hcl
project_id       = "your-project-id"
region           = "us-central1"
cluster_name     = "experimental-cluster"
experiment_group = "experimental"
```

### Use Default `terraform/main.tf`

**Keep both node pools** (this is already configured):

- On-Demand pool (fallback)
- Spot pool (primary, with taint)

### Use Default `k8s/deployment.yaml`

**Keep tolerations and affinity** (already configured):

- Prefer Spot nodes
- Tolerate Spot taints
- Fall back to On-Demand when Spot is unavailable

### Deploy & Run

```bash
cd terraform
terraform apply

cd ../k8s
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
kubectl apply -f hpa.yaml

cd ../scripts
bash run-experiments.sh
```

### Expected Results

- **Error Rate**: ~0% (should match Control A)
- **Cost**: Medium (40-60% savings vs Control A)
- **Failover Time**: <10s (fast rescheduling to On-Demand)

---

## Collecting Costs in GCP Console

After running all three experiments:

1. Go to [GCP Billing Console](https://console.cloud.google.com/billing)
2. Select **Reports**
3. Set **Time Range** to cover all experiments
4. Add **Group By**: `Labels → experiment-group`
5. You'll see three separate cost lines:
   - `experiment-group=control-a` (On-Demand baseline)
   - `experiment-group=control-b` (Spot-only)
   - `experiment-group=experimental` (Hybrid)

### Alternative: Filter by Cluster Name

If you used different cluster names:

- **Group By**: `Resource → GKE Cluster`
- Compare: `control-a-cluster`, `control-b-cluster`, `experimental-cluster`

---

## Cost Comparison Table

After collecting data, create a table like this:

| Metric                        | Control A (On-Demand) | Control B (Spot) | Experimental (Hybrid) |
| ----------------------------- | --------------------- | ---------------- | --------------------- |
| **Daily Cost**                | $X.XX                 | $Y.YY            | $Z.ZZ                 |
| **Cost Savings vs Control A** | 0%                    | ~70%             | ~50%                  |
| **Error Rate**                | 0%                    | >5%              | ~0%                   |
| **Failover Time**             | N/A                   | >30s             | <10s                  |
| **Reliability**               | 100%                  | <95%             | ~100%                 |

---

## Simplified Workflow (Recommended)

Instead of modifying `main.tf` for each group, create **three separate Terraform directories**:

```
terraform-control-a/
  ├── main.tf (on-demand only)
  ├── variables.tf
  └── terraform.tfvars (experiment_group = "control-a")

terraform-control-b/
  ├── main.tf (spot only, no taint)
  ├── variables.tf
  └── terraform.tfvars (experiment_group = "control-b")

terraform-experimental/
  ├── main.tf (hybrid, current config)
  ├── variables.tf
  └── terraform.tfvars (experiment_group = "experimental")
```

This way you can run all three in parallel (in different GCP projects or regions) and compare results simultaneously.

---

## Summary

**To answer your question**: You separate costs by using the `experiment-group` label:

1. **In GCP Billing**: Filter/Group by `Labels → experiment-group`
2. **Values**:
   - `control-a` = On-Demand only
   - `control-b` = Spot only
   - `experimental` = Hybrid (Spot + On-Demand)

This allows you to see exactly how much each configuration costs, even though they all use Spot nodes (in groups B and Experimental).
