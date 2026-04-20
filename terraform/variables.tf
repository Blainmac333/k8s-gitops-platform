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
  default     = "3900c0d6-5fbd-4b25-b021-182baa1f5976"
}
