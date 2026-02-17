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

# ─── Spoke VNet ──────────────────────────────────────────────────────────────

module "spoke" {
  source = "../../"

  name               = "vnet-spoke-eastus2-dev"
  location           = "eastus2"
  vnet_address_space = ["10.1.0.0/16"]

  subnets = {
    priv-app  = ["10.1.1.0/24"]
    priv-data = ["10.1.2.0/24"]
  }

  peerings = {
    # ── Scenario 1: Full VNet peering (bi-directional, mirror-forward) ─────
    to-hub = {
      remote_virtual_network_resource_id = azurerm_virtual_network.hub.id
      allow_forwarded_traffic            = true
      use_remote_gateways                = true

      create_reverse_peering      = true
      reverse_name                = "peer-hub-to-spoke"
      reverse_use_remote_gateways = false          # hub side doesn't use spoke's gateways
      reverse_allow_gateway_transit = true          # hub allows gateway transit to spoke
    }

    # ── Scenario 2: Address-space scoped peering ───────────────────────────
    to-shared = {
      remote_virtual_network_resource_id = azurerm_virtual_network.shared.id
      peer_complete_vnets                = false

      local_peered_address_spaces  = [{ address_prefix = "10.1.1.0/24" }]
      remote_peered_address_spaces = [{ address_prefix = "10.2.1.0/24" }]

      # Reverse auto-swaps: shared sees 10.2.1.0/24 as local, 10.1.1.0/24 as remote
      create_reverse_peering = true
      reverse_name           = "peer-shared-to-spoke"
    }

    # ── Scenario 3: Subnet-scoped peering ──────────────────────────────────
    to-data = {
      remote_virtual_network_resource_id = azurerm_virtual_network.data.id
      peer_complete_vnets                = false

      local_peered_subnets  = [{ subnet_name = "priv-app" }]
      remote_peered_subnets = [{ subnet_name = "priv-db" }]

      create_reverse_peering = true
      reverse_name           = "peer-data-to-spoke"
    }

    # ── Scenario 4: Forward-only peering (no reverse) ──────────────────────
    to-monitoring = {
      remote_virtual_network_resource_id = azurerm_virtual_network.monitoring.id
      allow_forwarded_traffic            = true
    }
  }

  tags = {
    Environment = "dev"
    Project     = "peering-example"
  }
}

# ─── Peer VNets (stubs for the example) ─────────────────────────────────────

resource "azurerm_resource_group" "peers" {
  name     = "rg-peer-targets-eastus2-dev"
  location = "eastus2"
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub-eastus2-dev"
  location            = azurerm_resource_group.peers.location
  resource_group_name = azurerm_resource_group.peers.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_virtual_network" "shared" {
  name                = "vnet-shared-eastus2-dev"
  location            = azurerm_resource_group.peers.location
  resource_group_name = azurerm_resource_group.peers.name
  address_space       = ["10.2.0.0/16"]
}

resource "azurerm_virtual_network" "data" {
  name                = "vnet-data-eastus2-dev"
  location            = azurerm_resource_group.peers.location
  resource_group_name = azurerm_resource_group.peers.name
  address_space       = ["10.3.0.0/16"]
}

resource "azurerm_virtual_network" "monitoring" {
  name                = "vnet-monitoring-eastus2-dev"
  location            = azurerm_resource_group.peers.location
  resource_group_name = azurerm_resource_group.peers.name
  address_space       = ["10.4.0.0/16"]
}

# ─── Outputs ─────────────────────────────────────────────────────────────────

output "spoke_vnet_id" {
  value = module.spoke.vnet_id
}

output "peering_ids" {
  value = module.spoke.peering_ids
}

output "peering_reverse_ids" {
  value = module.spoke.peering_reverse_ids
}
