variable "cloudflare_api_token" {
  description = "Cloudflare API token with DNS edit permissions for blainweb.com"
  type        = string
  sensitive   = true
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID for blainweb.com"
  type        = string
}

variable "tunnel_id" {
  description = "Cloudflare Tunnel UUID for qr-pi tunnel"
  type        = string
  default     = "d9c6665a-3358-4740-8f62-61fcedbedf26"
}
