output "reserved_ipv4" {
  description = "Stable public IPv4; set this as headscale_ipv4 in the Cloudflare module"
  value       = digitalocean_reserved_ip.headscale.ip_address
}

output "droplet_ipv4" {
  description = "Droplet's own IPv4 (changes on rebuild)"
  value       = digitalocean_droplet.headscale.ipv4_address
}

output "droplet_ipv6" {
  description = "Droplet's own IPv6 (changes on rebuild)"
  value       = digitalocean_droplet.headscale.ipv6_address
}
