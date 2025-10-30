# Proxmox Connection Variables
variable "proxmox_endpoint" {
  description = "Proxmox API endpoint"
  type        = string
}
variable "proxmox_api_token" {
  description = "Proxmox API token ID (format: user@realm!tokenname)"
  type        = string
}
variable "proxmox_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

# Proxmox Nodes
variable "proxmox_nodes" {
  description = "Map of Proxmox nodes with their "
  type        = list(
    object({
      node_name        = string
      template_id = number
    })
  )
}

# Kubernetes Cluster Variables
variable "cluster_name" {
  description = "Name of the Kubernetes cluster"
  type        = string
  default     = "talos-k8s-cluster"
}

variable "cluster_endpoint" {
  description = "Kubernetes API server endpoint"
  type        = string
  default     = "https://10.0.10.10:6443"
}
