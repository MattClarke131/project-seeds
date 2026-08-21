locals {
  dns_records = merge(
    { for h in var.tunnel_hostnames : h => var.edge_proxy_ipv4 },
    { for h in var.headscale_hostnames : h => var.headscale_ipv4 },
    { for h in var.tailnet_assistant_hostnames : h => var.tailnet_assistant_ipv4 },
  )
}
