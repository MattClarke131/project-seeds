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
  description = "Proxmox host and VM resource allocation"
  type = list(object({
    name             = string
    host_ip          = string
    cores            = number
    memory_mb        = number
    host_reserved_mb = number
    template_vm_id   = number

    control_plane    = object({
      ip_address       = string
      mac_address      = string
      cores            = number
      memory_mb        = number
    })

    workers          = list(object({
      ip_address       = string
      mac_address      = string
      cores            = number
      memory_mb        = number
    }))
  }))

  validation {
    condition = alltrue([
      for host in var.proxmox_hosts :
      (host.control_plane.memory_mb + sum([for w in host.workers : w.memory_mb]) + host.host_reserved_mb) <= host.memory_mb])

      error_message = "Total VM memory allocation + host_reserved_mb exceeds total host memory on one or more hosts."
  }

  default = [
    {
      name = "proxmox1", host_ip = "10.0.10.30", cores = 4, memory_mb = 16384, host_reserved_mb = 4096, template_vm_id = 10000,

      control_plane = { ip_address = "10.0.10.31", mac_address = "02:00:00:00:30:01", cores = 4, memory_mb = 4096, }
      workers = [
        { ip_address = "10.0.10.32", mac_address = "02:00:00:00:30:02", cores = 4, memory_mb = 4096, },
        { ip_address = "10.0.10.33", mac_address = "02:00:00:00:30:03", cores = 4, memory_mb = 4096, },
      ]
    },
    {
      name = "proxmox2", host_ip = "10.0.10.40", cores = 4, memory_mb = 16384, host_reserved_mb = 4096, template_vm_id = 20000,

      control_plane = { ip_address = "10.0.10.41", mac_address = "02:00:00:00:40:01", cores = 4, memory_mb = 4096, }
      workers = [
        { ip_address = "10.0.10.42", mac_address = "02:00:00:00:40:02", cores = 4, memory_mb = 4096, },
        { ip_address = "10.0.10.43", mac_address = "02:00:00:00:40:03", cores = 4, memory_mb = 4096, },
      ]
    },
    {
      name = "proxmox3", host_ip = "10.0.10.50", cores = 4, memory_mb = 16384, host_reserved_mb = 4096, template_vm_id = 30000,

      control_plane = { ip_address = "10.0.10.51", mac_address = "02:00:00:00:50:01", cores = 4, memory_mb = 4096, }
      workers = [
        { ip_address = "10.0.10.52", mac_address = "02:00:00:00:50:02", cores = 4, memory_mb = 4096, },
        { ip_address = "10.0.10.53", mac_address = "02:00:00:00:50:03", cores = 4, memory_mb = 4096, },
      ]
    }
  ]
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

