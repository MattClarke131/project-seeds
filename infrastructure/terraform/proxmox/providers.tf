terraform {
  required_version = ">=1.13.4"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.85.1"
    }

    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.9.0"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  api_token = "${var.proxmox_api_token}=${var.proxmox_token_secret}"
  insecure = true # self-signed certs in homelab

  ssh {
    username = "root"
    password = var.proxmox_ssh_password
  }
}

provider "talos" {}
