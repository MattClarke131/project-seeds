terraform {
  required_version = ">=1.11.2"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.91"
    }

    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.9.0"
      # version = ">= 0.10.0"
    }

    http = {
      source  = "hashicorp/http"
      version = "~> 3.4"
    }
  }
}

provider "proxmox" {
  endpoint  = var.proxmox_host
  api_token = "${var.proxmox_token_id}=${var.proxmox_token_secret}"
  insecure  = true

  ssh {
    agent = true
  }
}

provider "talos" {}
