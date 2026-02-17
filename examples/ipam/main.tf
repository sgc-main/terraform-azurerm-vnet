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

# Reference an existing IPAM pool
data "azurerm_network_manager_ip_address_pool" "this" {
  name                    = "my-ipam-pool"
  network_manager_id      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-netmgr/providers/Microsoft.Network/networkManagers/nm-central"
  address_type            = "IPv4"
  ip_address_pool_name    = "my-ipam-pool"
}

locals {
  ipam_pool_id = data.azurerm_network_manager_ip_address_pool.this.id
}

module "vnet" {
  source = "../../"

  name     = "vnet-ipam-eastus2-dev"
  location = "eastus2"

  # VNet address space from IPAM (no hardcoded CIDR)
  ipam_pools = [{
    id            = local.ipam_pool_id
    prefix_length = 16
  }]

  # Subnet keys and prefix lengths — no var.subnets needed, IPAM allocates everything
  subnet_ipam_pools = {
    pub-appgw = [{ pool_id = local.ipam_pool_id, prefix_length = 24 }]
    priv-app  = [{ pool_id = local.ipam_pool_id, prefix_length = 24 }]
    priv-data = [{ pool_id = local.ipam_pool_id, prefix_length = 24 }]
    aks-node  = [{ pool_id = local.ipam_pool_id, prefix_length = 22 }]
    aks-pod   = [{ pool_id = local.ipam_pool_id, prefix_length = 21 }]
  }

  tags = {
    Environment = "dev"
    Project     = "ipam-example"
  }
}

# --- Outputs ---

output "vnet_id" {
  value = module.vnet.vnet_id
}

output "vnet_name" {
  value = module.vnet.vnet_name
}

output "subnet_ids" {
  value = module.vnet.subnet_ids
}

output "subnet_configuration" {
  value = module.vnet.subnet_configuration
}
