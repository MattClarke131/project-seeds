data "cloudflare_zone" "labmatt" {
  filter = {
    name = var.zone_name
  }
}

resource "cloudflare_dns_record" "wildcard" {
  zone_id = data.cloudflare_zone.labmatt.zone_id
  name    = "*"
  type    = "A"
  content = var.ingress_ip
  proxied = false
  ttl     = 1 # Auto
}

resource "cloudflare_dns_record" "record" {
  for_each = local.dns_records

  zone_id = data.cloudflare_zone.labmatt.zone_id
  name    = each.key
  type    = "A"
  content = each.value
  proxied = false
  ttl     = 1 # Auto
  comment = lookup(var.record_comments, each.key, null)
}
