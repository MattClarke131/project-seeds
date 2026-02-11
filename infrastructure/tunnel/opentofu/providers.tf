terraform {
  required_version = ">= 1.11.1"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = ">= 1.60.0"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}
