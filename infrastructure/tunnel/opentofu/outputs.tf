output "server_id" {
  description = "Hetzner server ID"
  value       = hcloud_server.edge_proxy.id
}

output "public_ipv4" {
  description = "Public IPv4 address of edge proxy (floating)"
  value       = hcloud_floating_ip.edge_proxy.ip_address
}

output "public_ipv6" {
  description = "Public IPv6 address of edge proxy"
  value       = hcloud_server.edge_proxy.ipv6_address
}
