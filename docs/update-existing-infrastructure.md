# Update Guide: Adding experiment-group Labels to Existing Infrastructure

Since you've already deployed your infrastructure with `terraform apply`, here's how to update it with the new `experiment-group` labels:

## Option 1: Simple Update (Recommended)

This will add the labels to your existing cluster without destroying anything.

### Step 1: Add the experiment_group variable to terraform.tfvars

Create or edit `terraform/terraform.tfvars`:

```hcl
project_id       = "your-project-id"  # Keep your existing value
region           = "us-central1"       # Keep your existing value
cluster_name     = "hybrid-cost-optimized-cluster"  # Keep your existing value
experiment_group = "experimental"      # NEW: Add this line
```

### Step 2: Run terraform plan to preview changes

```bash
cd terraform
terraform plan
```

You should see output like:

```
~ resource "google_container_cluster" "primary" {
    + resource_labels = {
        + "experiment-group" = "experimental"
      }
  }

~ resource "google_container_node_pool" "on_demand_nodes" {
    ~ labels = {
        + "experiment-group" = "experimental"
      }
  }

~ resource "google_container_node_pool" "spot_nodes" {
    ~ labels = {
        + "experiment-group" = "experimental"
      }
  }
```

The `~` means "update in-place" and `+` means "adding". This is safe - it won't destroy your cluster.

### Step 3: Apply the changes

```bash
terraform apply
```

Type `yes` when prompted.

**Result**: Your existing cluster will be updated with the new labels. No downtime, no pod restarts.

---

## Option 2: If You Get Errors

If Terraform shows that it needs to recreate resources (you'll see `-/+` or `destroy/create`), you have two options:

### Option 2a: Accept the Recreation (If you're okay with downtime)

```bash
terraform apply
```

This will:

1. Destroy the old cluster
2. Create a new one with labels
3. You'll need to redeploy your application (`kubectl apply -f k8s/`)

### Option 2b: Manual Label Addition (No Terraform)

If you want to avoid any Terraform changes, you can add labels manually using `gcloud`:

```bash
# Get your cluster name
CLUSTER_NAME="hybrid-cost-optimized-cluster"
REGION="us-central1"
PROJECT_ID=$(gcloud config get-value project)

# Add label to cluster
gcloud container clusters update $CLUSTER_NAME \
  --region=$REGION \
  --update-labels=experiment-group=experimental

# Add labels to node pools
gcloud container node-pools update on-demand-pool \
  --cluster=$CLUSTER_NAME \
  --region=$REGION \
  --node-labels=experiment-group=experimental

gcloud container node-pools update spot-pool \
  --cluster=$CLUSTER_NAME \
  --region=$REGION \
  --node-labels=experiment-group=experimental
```

Then update your Terraform state to match:

```bash
terraform refresh
```

---

## Verification

After updating, verify the labels are applied:

### Check Cluster Labels

```bash
gcloud container clusters describe hybrid-cost-optimized-cluster \
  --region=us-central1 \
  --format="value(resourceLabels)"
```

### Check Node Labels

```bash
kubectl get nodes --show-labels | grep experiment-group
```

You should see `experiment-group=experimental` in the output.

---

## Important Notes

> [!NOTE] > **For Future Experiments**: When you run Control Group A or B, you'll deploy **new clusters** with different `experiment_group` values (`control-a` or `control-b`). You don't need to modify this existing cluster.

> [!TIP] > **Cost Tracking**: The labels will appear in GCP Billing within 24 hours. Historical costs (before adding labels) won't be retroactively labeled.

---

## Quick Command Summary

```bash
# 1. Edit terraform.tfvars to add experiment_group = "experimental"

# 2. Preview changes
cd terraform
terraform plan

# 3. Apply changes
terraform apply

# 4. Verify
kubectl get nodes --show-labels | grep experiment-group
```

That's it! Your existing infrastructure will be updated with the new labels.
