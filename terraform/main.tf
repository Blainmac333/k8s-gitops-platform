terraform {
  required_version = ">= 1.5"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }

  cloud {
    organization = "blainweb"

    workspaces {
      name = "cloudflare-dns"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
