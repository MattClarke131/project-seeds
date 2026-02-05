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

# Proxmox Host Node Configuration
variable "proxmox_hosts" {
  description = "Proxmox host configuration"
  type = list(object({
    name           = string
    cores          = number
    memory_mb      = number
    template_vm_id = number
    ip_range_base  = string
  }))
  default = [
    { name = "node1", cores = 4, memory_mb = 4096, template_vm_id = 10000, ip_range_base = "10.0.10.10" },
    { name = "node2", cores = 4, memory_mb = 4096, template_vm_id = 20000, ip_range_base = "10.0.10.20" },
    { name = "node3", cores = 4, memory_mb = 4096, template_vm_id = 30000, ip_range_base = "10.0.10.30" },
  ]
}

variable "bootstrap_node_name" {
  description = "Proxmox node name for the bootstrap control plane"
  type        = string
  default     = "node1"
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

