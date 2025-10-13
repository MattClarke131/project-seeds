terraform {
  required_version = ">=1.13.4"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.85.1"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  api_token = "${var.proxmox_api_token}=${var.proxmox_token_secret}"
  insecure = true # self-signed certs in homelab

  ssh {
    agent = true
  }
}
