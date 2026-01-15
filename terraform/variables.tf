variable "project_id" {
  description = "The GCP Project ID"
  type        = string
}

variable "region" {
  description = "The GCP Region"
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "The name of the GKE cluster"
  type        = string
  default     = "hybrid-cost-optimized-cluster"
}

variable "experiment_group" {
  description = "Experiment group identifier for cost tracking: control-a (on-demand), control-b (spot-only), or experimental (hybrid)"
  type        = string
  default     = "experimental"
  
  validation {
    condition     = contains(["control-a", "control-b", "experimental"], var.experiment_group)
    error_message = "experiment_group must be one of: control-a, control-b, experimental"
  }
}
