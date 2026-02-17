terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

# ─── Hub VNet with VPN Gateway ──────────────────────────────────────────────

module "hub" {
  source = "../../"

  name               = "vnet-hub-eastus2-prod"
  location           = "eastus2"
  vnet_address_space = ["10.100.0.0/16"]

  subnets = {
    GatewaySubnet = ["10.100.0.64/27"]   # Required for VPN — /27 minimum
    priv-app      = ["10.100.1.0/24"]
    priv-data     = ["10.100.2.0/24"]
  }

  # ── VPN Gateway ────────────────────────────────────────────────────────────
  enable_vpn_gateway = true
  vpn_gateway_sku    = "VpnGw2"

  vpn_connections = {
    # ── Scenario 1: Static routing with custom IPsec policy ──────────────
    to-datacenter = {
      peer_ip_address = "198.51.100.1"
      shared_key      = var.vpn_shared_key_dc
      address_space   = ["192.168.0.0/16"]

      ipsec_policy = {
        ike_encryption   = "AES256"
        ike_integrity    = "SHA256"
        dh_group         = "DHGroup14"
        ipsec_encryption = "AES256"
        ipsec_integrity  = "SHA256"
        pfs_group        = "PFS14"
        sa_lifetime      = 3600
      }
    }

    # ── Scenario 2: BGP-enabled tunnel (e.g. AWS VPN) ────────────────────
    to-aws-primary = {
      peer_ip_address     = "203.0.113.1"
      shared_key          = var.vpn_shared_key_aws
      enable_bgp          = true
      bgp_asn             = 64512
      bgp_peering_address = "169.254.21.1"

      ipsec_policy = {
        ike_encryption   = "AES256"
        ike_integrity    = "SHA256"
        dh_group         = "DHGroup14"
        ipsec_encryption = "AES256"
        ipsec_integrity  = "SHA256"
        pfs_group        = "PFS14"
        sa_lifetime      = 3600
      }
    }

    # ── Scenario 3: Second BGP tunnel for redundancy ─────────────────────
    to-aws-secondary = {
      peer_ip_address     = "203.0.113.2"
      shared_key          = var.vpn_shared_key_aws
      enable_bgp          = true
      bgp_asn             = 64512
      bgp_peering_address = "169.254.22.1"

      ipsec_policy = {
        ike_encryption   = "AES256"
        ike_integrity    = "SHA256"
        dh_group         = "DHGroup14"
        ipsec_encryption = "AES256"
        ipsec_integrity  = "SHA256"
        pfs_group        = "PFS14"
        sa_lifetime      = 3600
      }
    }

    # ── Scenario 4: Simple static tunnel (Azure defaults) ────────────────
    to-branch = {
      peer_ip_address = "192.0.2.1"
      shared_key      = var.vpn_shared_key_branch
      address_space   = ["10.200.0.0/16"]
    }
  }

  # ── Peering to a spoke VNet (gateway transit) ──────────────────────────────
  peerings = {
    to-spoke = {
      remote_virtual_network_resource_id = module.spoke.vnet_id
      allow_forwarded_traffic            = true
      allow_gateway_transit              = true
      create_reverse_peering             = true
      reverse_name                       = "peer-spoke-to-hub"
      reverse_use_remote_gateways        = true
    }
  }

  tags = {
    Environment = "prod"
    Project     = "vpn-example"
  }
}

# ─── Spoke VNet (uses hub gateway via peering) ──────────────────────────────

module "spoke" {
  source = "../../"

  name               = "vnet-spoke-eastus2-prod"
  location           = "eastus2"
  vnet_address_space = ["10.101.0.0/16"]

  subnets = {
    priv-app  = ["10.101.1.0/24"]
    priv-data = ["10.101.2.0/24"]
  }

  tags = {
    Environment = "prod"
    Project     = "vpn-example"
  }
}

# ─── Variables ───────────────────────────────────────────────────────────────

variable vpn_shared_key_dc {
  description = "Pre-shared key for datacenter VPN tunnel"
  type        = string
  sensitive   = true
}

variable vpn_shared_key_aws {
  description = "Pre-shared key for AWS VPN tunnels"
  type        = string
  sensitive   = true
}

variable vpn_shared_key_branch {
  description = "Pre-shared key for branch office VPN tunnel"
  type        = string
  sensitive   = true
}

# ─── Outputs ─────────────────────────────────────────────────────────────────

output "vpn_gateway_id" {
  description = "VPN Gateway resource ID"
  value       = module.hub.vpn_gateway_id
}

output "vpn_gateway_public_ip" {
  description = "Public IP of the VPN gateway — configure on remote side"
  value       = module.hub.vpn_gateway_public_ip
}

output "vpn_gateway_bgp_settings" {
  description = "BGP settings (ASN + peering addresses) for remote peer configuration"
  value       = module.hub.vpn_gateway_bgp_settings
}

output "vpn_connection_ids" {
  description = "Map of connection names to resource IDs"
  value       = module.hub.vpn_connection_ids
}

output "hub_vnet_id" {
  description = "Hub VNet resource ID"
  value       = module.hub.vnet_id
}

output "spoke_vnet_id" {
  description = "Spoke VNet resource ID"
  value       = module.spoke.vnet_id
}
