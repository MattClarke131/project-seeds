variable "do_token" {
  description = "DigitalOcean API token with read/write scope"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "Public SSH key for the matt user (contents of e.g. ~/.ssh/id_ed25519.pub)"
  type        = string
}

variable "droplet_name" {
  description = "Droplet name and hostname"
  type        = string
  default     = "elendira"
}

variable "region" {
  description = "DigitalOcean region for the droplet and its reserved IP"
  type        = string
  default     = "nyc3" # nyc2 no longer accepts new droplets
}

variable "size" {
  description = "Droplet size slug"
  type        = string
  default     = "s-1vcpu-512mb-10gb"
}

variable "image" {
  description = "Droplet image slug"
  type        = string
  default     = "ubuntu-26-04-x64"
}

variable "headscale_hostname" {
  description = "Public hostname clients use to reach Headscale"
  type        = string
  default     = "headscale.labmatt.com"
}

variable "headscale_version" {
  description = "Headscale release installed on first boot (no leading v)"
  type        = string
  default     = "0.28.0"
}

variable "headscale_deb_sha256" {
  description = "SHA-256 of headscale_<version>_linux_amd64.deb, from the release's checksums.txt"
  type        = string
  default     = "8c3afb2e950e060d21bdefa98cda3accdcc1cb893bbed2e94a58de25a42f6dbe"
}

variable "ssh_source_addresses" {
  description = "CIDRs allowed to reach SSH; the box isn't on the tailnet it serves, so SSH stays public by default"
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]
}
