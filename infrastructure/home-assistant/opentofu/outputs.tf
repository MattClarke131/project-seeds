output "home_assistant_ip" {
  description = "Home Assistant VM IP address"
  value       = var.proxmox_node.home_assistant.ip_address
}

output "home_assistant_url" {
  description = "Home Assistant web UI"
  value       = "http://${var.proxmox_node.home_assistant.ip_address}:8123"
}
