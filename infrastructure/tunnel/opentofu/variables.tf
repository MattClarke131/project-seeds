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

variable "ssh_public_key" {
  description = "Public SSH key installed on the edge proxy server (contents of e.g. ~/.ssh/id_ed25519.pub). Must include the trailing newline (set it as a heredoc in terraform.tfvars) - a value without one differs from what's already in state and forces the key, server, and floating IP to be replaced."
  type        = string
}

