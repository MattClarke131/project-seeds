resource "digitalocean_ssh_key" "homelab" {
  name       = "homelab-key"
  public_key = var.ssh_public_key
}

resource "digitalocean_droplet" "headscale" {
  name     = var.droplet_name
  region   = var.region
  size     = var.size
  image    = var.image
  ipv6     = true
  ssh_keys = [digitalocean_ssh_key.homelab.id]

  user_data = templatefile("${path.module}/cloud-init.yaml.tftpl", {
    hostname             = var.droplet_name
    ssh_public_key       = trimspace(var.ssh_public_key)
    headscale_version    = var.headscale_version
    headscale_deb_sha256 = var.headscale_deb_sha256
    headscale_config = templatefile("${path.module}/headscale-config.yaml", {
      headscale_hostname = var.headscale_hostname
    })
  })

  # user_data and image force a replacement; rebuild deliberately with -replace (see README)
  lifecycle {
    ignore_changes = [user_data, image]
  }
}

# DNS points here, so rebuilding the droplet doesn't change the address clients use
resource "digitalocean_reserved_ip" "headscale" {
  region = var.region

  lifecycle {
    prevent_destroy = true
  }
}

resource "digitalocean_reserved_ip_assignment" "headscale" {
  ip_address = digitalocean_reserved_ip.headscale.ip_address
  droplet_id = digitalocean_droplet.headscale.id
}

resource "digitalocean_firewall" "headscale" {
  name        = var.droplet_name
  droplet_ids = [digitalocean_droplet.headscale.id]

  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = var.ssh_source_addresses
  }

  # 80 serves the Let's Encrypt HTTP-01 challenge; 443 is the control plane
  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  inbound_rule {
    protocol         = "icmp"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }

  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}
