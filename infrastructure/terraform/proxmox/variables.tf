# Proxmox Configuration
variable "proxmox_host" {
  description = "Proxmox API endpoint"
  type        = string
}

variable "proxmox_token_id" {
  description = "Proxmox API token ID"
  type        = string
}

variable "proxmox_token_secret" {
  description = "Proxmox API token secret"
  type        = string
  sensitive   = true
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
  default     = "k8sVNet"
}

# Proxmox Host Node Configuration
variable "proxmox_hosts" {
  description = "Proxmox host configuration"
  type = map(object({
    cores          = number
    memory_mb      = number
    template_vm_id = number
    ip_range_base  = string
  }))
  default = {
    node1 = { cores = 4, memory_mb = 4096, template_vm_id = 9000, ip_range_base = "10.0.10.10" }
    node2 = { cores = 4, memory_mb = 4096, template_vm_id = 9001, ip_range_base = "10.0.10.20" }
    node3 = { cores = 4, memory_mb = 4096, template_vm_id = 9002, ip_range_base = "10.0.10.30" }
  }
}

# Bootstrap Control Plane Node
# In the future, all control planes could be gateways, but for simplicity,
# we designate one as the bootstrap and only gateway node.
variable "bootstrap_node_name" {
  description = "Proxmox node name for the bootstrap control plane. Is the only gateway node."
  type        = string
  default     = "node1"
}
