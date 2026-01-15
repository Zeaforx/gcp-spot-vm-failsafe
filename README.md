# Optimizing Kubernetes Costs: Hybrid Spot/On-Demand Strategy

This project implements and tests a cost-optimization strategy for Kubernetes clusters on Google Cloud Platform (GKE). It demonstrates a hybrid node pool approach that leverages cheap **Spot VMs** for primary workloads and falls back to **On-Demand VMs** for reliability, achieving significant cost savings without sacrificing uptime.

## 📌 Project Overview

The goal involves running a CPU-intensive "Image Processing Service" across three experimental groups to measure cost, reliability, and performance:

1.  **Control Group A (On-Demand Only)**: Baseline for maximum stability and highest cost.
2.  **Control Group B (Spot Only)**: high-risk, low-cost baseline to quantify the "cost of failure" (preemption).
3.  **Experimental Group (Hybrid)**: The proposed solution utilizing Spot nodes with On-Demand fallback.

## 📂 Project Structure

- **`app/`**: Contains the Go-based "Image Processing Service" application and Dockerfile.
- **`terraform/`**: Infrastructure-as-Code to provision GKE clusters and Node Pools (Spot & On-Demand).
- **`k8s/`**: Kubernetes manifests (Deployment, Service, HPA) with node affinity and tolerations.
- **`scripts/`**: Automation scripts for installing monitoring, running experiments, etc.
- **`tests/`**: JMeter load testing configurations (`.jmx`) to simulate traffic.
- **`docs/`**: Detailed guides on infrastructure updates and running experiments.
- **`configs/`**: Configuration files for monitoring and other services.

## 🛠 Prerequisites

Ensure you have the following installed locally:

- **[Google Cloud SDK (gcloud)](https://cloud.google.com/sdk/docs/install)**
- **[Terraform](https://developer.hashicorp.com/terraform/install)**
- **[kubectl](https://kubernetes.io/docs/tasks/tools/)**
- **[Helm](https://helm.sh/docs/intro/install/)** (for monitoring)
- **[Go](https://go.dev/doc/install)** (optional, for building app locally)
- **[Apache JMeter](https://jmeter.apache.org/download_jmeter.cgi)** (for running load tests)

## 🚀 Getting Started

### 1. Setup Infrastructure

Configure and deploy the GKE cluster using Terraform.

```bash
cd terraform
# Initialize Terraform
terraform init

# Create a 'terraform.tfvars' file with your project details
# (See docs/experimental-groups-guide.md for configuration specific to each experiment)

# Apply infrastructure
terraform apply
```

### 2. Configure Kubectl

Connect your local `kubectl` to the newly created cluster.

```bash
gcloud container clusters get-credentials <your-cluster-name> --region <your-region>
```

### 3. Deploy Application

Deploy the image processing service to the cluster.

```bash
# Export your Project ID
export GOOGLE_PROJECT_ID=<your-project-id>

# Run the deployment script
cd scripts
bash deploy-app.sh
```

### 4. Install Monitoring

Install the Prometheus and Grafana stack to track node availability, pod status, and costs.

```bash
cd scripts
./install-monitoring.sh
```

**Accessing Dashboards:**

- **Grafana**: `http://localhost:3000` (User: `admin`, Pass: `admin`)
- **Prometheus**: `http://localhost:9090`

## 🔬 Running Experiments

Refer to the **[Experimental Groups Guide](docs/experimental-groups-guide.md)** for detailed instructions on how to configure and run each of the three experiments:

1.  **Control A**: Edit `terraform.tfvars` to `experiment_group = "control-a"` and disable Spot pool.
2.  **Control B**: Edit `terraform.tfvars` to `experiment_group = "control-b"` and disable On-Demand pool.
3.  **Experimental**: Edit `terraform.tfvars` to `experiment_group = "experimental"` and enable both pools.

## 📊 Cost Tracking

Costs are tracked via GCP Billing using the `experiment-group` resource label applied to the cluster and nodes.
To view costs:

1. Go to **GCP Billing > Reports**.
2. Group by **Label** -> **experiment-group**.

## 🧪 Load Testing

Use JMeter to simulate separate traffic patterns (Normal vs. Spike) to stress-test the autoscaling and failover mechanisms.

```bash
# Open the test plan
jmeter -t tests/load-test-jmeter.jmx
```
