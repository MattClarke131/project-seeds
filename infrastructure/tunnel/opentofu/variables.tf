variable "server_name" {
  description = "Name for the edge proxy server"
  type        = string
  default     = "edge-proxy"
}

variable "server_type" {
  description = "Type of the Hetzner Cloud server (e.g., cx31, cx41, etc.)"
  type        = string
  default     = "cx23"
}

variable "location" {
  description = "Location for the Hetzner Cloud server (e.g., fsn1, nbg1, etc.)"
  type        = string
  default     = "nbg1" # Nuremberg
}

variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true
}

