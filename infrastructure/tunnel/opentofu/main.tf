resource "hcloud_ssh_key" "homelab" {
  name       = "homelab-key"
  public_key = file("~/.ssh/id_ed25519.pub")
}

resource "hcloud_server" "edge_proxy" {
  name        = var.server_name
  server_type = var.server_type
  location    = var.location
  image       = "ubuntu-24.04"
  
  ssh_keys = [hcloud_ssh_key.homelab.id]
  
  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  user_data = <<-EOF
  #cloud-config
  write_files:
    - path: /etc/netplan/60-floating-ip.yaml
      content: |
        network:
          version: 2
          ethernets:
            eth0:
              addresses:
                - ${hcloud_floating_ip.edge_proxy.ip_address}/32
  runcmd:
    - netplan apply
EOF
}

resource "hcloud_floating_ip" "edge_proxy" {
  type          = "ipv4"
  home_location = var.location
  description   = "Static IP for edge proxy"

  lifecycle {
    prevent_destroy = true
  }
}


resource "hcloud_floating_ip_assignment" "edge_proxy" {
  floating_ip_id = hcloud_floating_ip.edge_proxy.id
  server_id      = hcloud_server.edge_proxy.id
}
