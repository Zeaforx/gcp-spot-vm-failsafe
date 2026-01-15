resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name
  
  # IP allocation policy for pods and services
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }
  
  # Labels for cost tracking across experiment groups
  resource_labels = {
    "experiment-group" = var.experiment_group
  }
  
  # Allow Terraform to destroy the cluster
  deletion_protection = false
}

# Node Pool 1: On-Demand (Fallback / System)
resource "google_container_node_pool" "on_demand_nodes" {
  count      = var.experiment_group == "control-a" || var.experiment_group == "experimental" ? 1 : 0
  name       = "on-demand-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    machine_type = "e2-medium"
    disk_size_gb = 50
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    
    # Labels to identify this pool
    labels = {
      "node-type"        = "on-demand"
      "experiment-group" = var.experiment_group
    }
  }
}

# Node Pool 2: Spot (Primary Workload)
resource "google_container_node_pool" "spot_nodes" {
  count    = var.experiment_group == "control-b" || var.experiment_group == "experimental" ? 1 : 0
  name     = "spot-pool"
  location = var.region
  cluster  = google_container_cluster.primary.name
  
  # Autoscaling configuration
  autoscaling {
    min_node_count = 0
    max_node_count = 10
  }
  
  # Note: initial_node_count is ignored when autoscaling is enabled
  # but required by Terraform
  initial_node_count = 1

  node_config {
    machine_type = "e2-medium"
    disk_size_gb = 50
    spot         = true  # Enables Spot provisioning model

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Taints to prevent non-tolerant pods from scheduling here
    taint {
      key    = "node-type"
      value  = "spot"
      effect = "NO_SCHEDULE"
    }

    # Labels for Affinity rules
    labels = {
      "node-type"                 = "spot"
      "cloud.google.com/gke-spot" = "true"
      "experiment-group"          = var.experiment_group
    }
  }
}
