variable "cloudflare_api_token" {
  description = "Cloudflare API token scoped to the labmatt.com zone (Zone:DNS:Edit, Zone:Zone:Read)"
  type        = string
  sensitive   = true
}

variable "zone_name" {
  description = "Cloudflare zone to manage"
  type        = string
  default     = "labmatt.com"
}

variable "ingress_ip" {
  description = "Internal ingress-nginx LoadBalancer IP on the k8sVNet"
  type        = string
  default     = "10.0.10.2"
}

variable "edge_proxy_ipv4" {
  description = "Public IPv4 of the Hetzner edge proxy (Pangolin tunnel), from infrastructure/tunnel/opentofu output public_ipv4"
  type        = string
}

variable "headscale_ipv4" {
  description = "Public IPv4 of the headscale server VPS"
  type        = string
  default     = "107.170.31.230"
}

variable "tailnet_assistant_ipv4" {
  description = "Tailscale IP of the Home Assistant VM (snakAssistant)"
  type        = string
  default     = "100.64.0.3"
}

variable "tunnel_hostnames" {
  description = "Subdomains routed through the Pangolin tunnel on the Hetzner edge proxy"
  type        = set(string)
  default = [
    "books-sync",
    "gimme",
    "leantime",
    "mattflix",
    "pangolin",
    "pangolin-test",
  ]
}

variable "headscale_hostnames" {
  description = "Subdomains pointing at the headscale server VPS"
  type        = set(string)
  default = [
    "headscale",
  ]
}

variable "record_comments" {
  description = "Optional Cloudflare dashboard comment per hostname, for records that had one before import"
  type        = map(string)
  default = {
    headscale = "headscale server. running behind nginx on vps"
  }
}

variable "tailnet_assistant_hostnames" {
  description = "Subdomains pointing at the Home Assistant VM over Tailscale"
  type        = set(string)
  default = [
    "snakassistant",
  ]
}
