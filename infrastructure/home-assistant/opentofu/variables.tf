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

variable "proxmox_node" {
  description = "Proxmox node configuration"
  type = object({
    name             = string
    host_ip          = string
    cores            = number
    memory_mb        = number
    host_reserved_mb = number

    home_assistant = object({
      ip_address = string
      cores      = number
      memory_mb  = number
    })
  })

  validation {
    condition     = (var.proxmox_node.home_assistant.memory_mb + var.proxmox_node.host_reserved_mb) <= var.proxmox_node.memory_mb
    error_message = "VM memory + host_reserved_mb exceeds total host memory."
  }

  default = {
    name             = "proxAssistantHost"
    host_ip          = "100.64.0.1"
    cores            = 4
    memory_mb        = 16384
    host_reserved_mb = 4096

    home_assistant = {
      ip_address = "100.64.0.2"
      cores      = 4
      memory_mb  = 12288
    }
  }
}

variable "vm_id" {
  description = "VM ID for the Home Assistant VM"
  type        = number
  default     = 100
}
