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

module "vnet" {
  source = "../../"

  name               = "vnet-complete-eastus2-stg"
  location           = "eastus2"
  vnet_address_space = ["10.20.0.0/16"]

  subnets = {
    GatewaySubnet = ["10.20.0.64/27"]   # VPN/ExpressRoute — exact name, no NSG/NAT/RT
    pub-appgw     = ["10.20.0.0/24"]
    pub-bastion   = ["10.20.1.0/26"]
    priv-app      = ["10.20.2.0/24"]
    priv-data     = ["10.20.3.0/24"]
    priv-ilb      = ["10.20.4.0/24"]
    priv-func     = ["10.20.5.0/24"]
    aks-node      = ["10.20.8.0/22"]
    aks-pod       = ["10.20.16.0/20"]
  }

  tags = {
    Environment = "stg"
    Project     = "complete-example"
    CostCenter  = "12345"
  }

  # --- NSG Rules ---
  nsg_rules = {
    "allow-https-inbound" = {
      priority                   = 100
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "*"
      destination_address_prefix = "VirtualNetwork"
      description                = "Allow HTTPS inbound from any source"
    }
    "deny-all-inbound" = {
      priority                   = 4096
      direction                  = "Inbound"
      access                     = "Deny"
      protocol                   = "*"
      source_port_range          = "*"
      destination_port_range     = "*"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
      description                = "Deny all other inbound traffic"
    }
  }

  # --- Azure Firewall routing ---
  use_azure_firewall        = true
  azure_firewall_private_ip = "10.100.0.4"

  # --- Service endpoint extensions ---
  extra_service_endpoints     = ["Microsoft.Sql", "Microsoft.EventHub"]
  extra_aks_service_endpoints = ["Microsoft.EventHub"]

  # --- Private Link Services ---
  # Only priv-ilb subnet will have network policies disabled for PLS
  private_link_subnets = ["priv-ilb"]

  # --- Custom delegation override ---
  # Override auto-detected delegation for priv-data with SQL Managed Instance
  subnet_delegations = {
    "priv-data" = [{
      name = "Microsoft.Sql.managedInstances"
      service_delegation = {
        name = "Microsoft.Sql/managedInstances"
      }
    }]
  }

  # --- Feature toggles (all defaults shown for clarity) ---
  enable_nat_gateway            = true
  enable_nsg                    = true
  enable_route_table            = true
  enable_service_endpoints      = true
  enable_web_delegation         = true    # priv-func gets Web/serverFarms delegation
  enable_app_gateway_delegation = true    # pub-appgw gets App Gateway delegation
}

# ═══════════════════════════════════════════════════════════════════════════════
# DNS Hub VNet — hosts the Azure DNS Private Resolver
# Provides centralized DNS resolution for all spoke VNets, cross-tenant,
# and hybrid (AWS/on-prem) name resolution.
# ═══════════════════════════════════════════════════════════════════════════════

module "hub_vnet" {
  source = "../../"

  name               = "vnet-hub-eastus2-stg"
  location           = "eastus2"
  vnet_address_space = ["10.21.0.0/24"]

  subnets = {
    snet-dns-inbound  = ["10.21.0.0/28"]
    snet-dns-outbound = ["10.21.0.16/28"]
  }

  tags = {
    Environment = "stg"
    Project     = "complete-example"
    CostCenter  = "12345"
    Role        = "dns-hub"
  }

  # DNS resolver subnets require explicit delegation
  subnet_delegations = {
    "snet-dns-inbound" = [{
      name = "Microsoft.Network.dnsResolvers"
      service_delegation = {
        name    = "Microsoft.Network/dnsResolvers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }]
    "snet-dns-outbound" = [{
      name = "Microsoft.Network.dnsResolvers"
      service_delegation = {
        name    = "Microsoft.Network/dnsResolvers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }]
  }

  # Hub VNet — no workload resources, just DNS
  enable_nat_gateway       = false
  enable_service_endpoints = false

  # Peer hub ↔ spoke for DNS traffic
  peerings = {
    to-spoke = {
      name                               = "peer-hub-to-spoke"
      remote_virtual_network_resource_id = module.vnet.vnet_id
      allow_forwarded_traffic            = true
      create_reverse_peering             = true
      reverse_name                       = "peer-spoke-to-hub"
    }
  }
}

# --- Outputs ---

output "vnet_id" {
  value = module.vnet.vnet_id
}

output "vnet_name" {
  value = module.vnet.vnet_name
}

output "all_subnet_ids" {
  value = module.vnet.subnet_ids
}

output "public_subnet_ids" {
  value = module.vnet.public_subnet_ids
}

output "private_subnet_ids" {
  value = module.vnet.private_subnet_ids
}

output "nat_gateway_id" {
  value = module.vnet.nat_gateway_id
}

output "nsg_id" {
  value = module.vnet.nsg_id
}

output "resource_group_name" {
  value = module.vnet.resource_group_name
}

output "identity_principal_id" {
  value = module.vnet.user_assigned_identity_principal_id
}

output "subnet_configuration" {
  value = module.vnet.subnet_configuration
}

output "gateway_subnet_id" {
  value = module.vnet.gateway_subnet_id
}

# --- DNS Hub Outputs ---

output "hub_vnet_id" {
  value = module.hub_vnet.vnet_id
}

output "hub_dns_subnet_ids" {
  value = module.hub_vnet.subnet_ids
}

output "hub_peering_ids" {
  value = module.hub_vnet.peering_ids
}
