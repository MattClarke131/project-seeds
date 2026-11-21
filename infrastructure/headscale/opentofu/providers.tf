terraform {
  required_version = ">= 1.11.1"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = ">= 2.109.0"
    }
  }
}

provider "digitalocean" {
  token = var.do_token
}
