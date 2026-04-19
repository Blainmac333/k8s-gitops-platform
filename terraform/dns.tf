# blainweb.com subdomains routed through Cloudflare Tunnel qr-pi
locals {
  tunnel_cname = "${var.tunnel_id}.cfargotunnel.com"

  subdomains = {
    "qr"      = local.tunnel_cname
    "cv"      = local.tunnel_cname
    "grafana" = local.tunnel_cname
  }
}

resource "cloudflare_record" "tunnel_subdomains" {
  for_each = local.subdomains

  zone_id = var.cloudflare_zone_id
  name    = each.key
  content = each.value
  type    = "CNAME"
  proxied = true
}
