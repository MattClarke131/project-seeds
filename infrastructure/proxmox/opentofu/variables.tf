variable "proxmox_host" {
  description = "Proxmox API endpoint"
  type        = string
}

variable "proxmox_token_id" {
  description = "Proxmox API token ID (format: user@pve!token-name)"
  type        = string
}

variable "proxmox_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
}

variable "bootstrap_node_name" {
  description = "Proxmox node name for the bootstrap control plane"
  type        = string
  default     = "proxmox1"
}

# Cluster Configuration
variable "cluster_name" {
  description = "Kubernetes cluster name"
  type        = string
  default     = "k8s-cluster"
}

variable "proxmox_bridge" {
  description = "Proxmox bridge for k8s network"
  type        = string
  default     = "vmbr0"
}

