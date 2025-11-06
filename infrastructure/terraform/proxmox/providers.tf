terraform {
  required_version = ">=1.13.4"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.85"
    }

    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.9"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_host
  api_token = "${var.proxmox_token_id}=${var.proxmox_token_secret}"
  insecure = true

  ssh {
    agent = true
  }
}

provider "talos" {}
