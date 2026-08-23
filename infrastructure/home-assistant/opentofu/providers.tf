terraform {
  required_version = ">=1.11.2"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.91"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_host
  api_token = "${var.proxmox_token_id}=${var.proxmox_token_secret}"
  insecure  = true

  ssh {
  agent    = true
  username = "root"
  node {
    name    = var.proxmox_node.name
    address = var.proxmox_node.host_ip
    port    = 22
  }
}
}
