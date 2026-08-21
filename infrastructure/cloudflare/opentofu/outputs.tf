output "wildcard_record_id" {
  description = "Cloudflare record ID for the *.labmatt.com wildcard record"
  value       = cloudflare_dns_record.wildcard.id
}

output "record_ids" {
  description = "Cloudflare record IDs, keyed by subdomain"
  value       = { for k, r in cloudflare_dns_record.record : k => r.id }
}
