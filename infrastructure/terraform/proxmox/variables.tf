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

# Network Configuration
# variable "network_base_ip" {
#   description = "Base network (e.g., 10.0.10)"
#   type        = string
#   default     = "10.0.10"
# }

# variable "network_gateway" {
#   description = "Network gateway IP"
#   type        = string
#   default     = "10.0.10.1"
# }

variable "proxmox_bridge" {
  description = "Proxmox bridge for k8s network"
  type        = string
  default     = "k8sVNet"
}

# Node Configuration
# variable "proxmox_hosts" {
#   description = "Proxmox hosts with node allocation"
#   type = map(object({
#     control_planes = number
#     workers        = number
#     template_vm_id  = number
#   }))
#   default = {
#     node1 = { control_planes = 1, workers = 2, template_vm_id = 9000 }
#     node2 = { control_planes = 1, workers = 2, template_vm_id = 9001 }
#     node3 = { control_planes = 1, workers = 2, template_vm_id = 9002 }
#   }
# }
