# ─── Unit Tests for VNet Module ──────────────────────────────────────────────
# Uses mock providers to validate module logic without Azure credentials.
# Tests cover: subnet classification, naming, feature toggles, IPAM merging,
# public/private separation, and variable validation.

mock_provider "azurerm" {}

# Override submodule outputs to isolate root module logic — the azapi_resource
# `output` attribute (dynamic type) cannot be traversed by mock providers.
override_module {
  target = module.vnet
  outputs = {
    resource_id    = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test-vnet/providers/Microsoft.Network/virtualNetworks/test-vnet"
    name           = "test-vnet"
    address_spaces = ["10.0.0.0/16"]
    resource       = {}
  }
}

override_module {
  target = module.subnet
  outputs = {
    resource_id      = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test-vnet/providers/Microsoft.Network/virtualNetworks/test-vnet/subnets/mock"
    name             = "mock-subnet"
    address_prefixes = ["10.0.0.0/24"]
  }
}

override_module {
  target = module.peering
  outputs = {
    name                = "peer-test"
    resource_id         = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test-vnet/providers/Microsoft.Network/virtualNetworks/test-vnet/virtualNetworkPeerings/peer-test"
    reverse_name        = null
    reverse_resource_id = null
  }
}

override_module {
  target = module.vpn
  outputs = {
    gateway_id               = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test-vnet/providers/Microsoft.Network/virtualNetworkGateways/vpngw-test-vnet"
    gateway_name             = "vpngw-test-vnet"
    gateway_public_ip        = "20.0.0.1"
    gateway_public_ip_id     = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test-vnet/providers/Microsoft.Network/publicIPAddresses/pip-vpngw-test-vnet"
    gateway_secondary_public_ip = null
    gateway_bgp_settings     = null
    connection_ids           = {}
    local_network_gateway_ids = {}
  }
}

# Override resources whose mock-generated IDs would fail provider validation
# during apply (e.g. service_endpoint_storage_policy requires real-looking IDs)
override_resource {
  target = azurerm_resource_group.this
  values = {
    id       = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test-vnet"
    location = "eastus2"
    name     = "rg-test-vnet"
  }
}

override_resource {
  target = azurerm_storage_account.this
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test-vnet/providers/Microsoft.Storage/storageAccounts/satestvnet"
  }
}

override_resource {
  target = azurerm_nat_gateway.this
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test-vnet/providers/Microsoft.Network/natGateways/ngw-test-vnet"
  }
}

override_resource {
  target = azurerm_network_security_group.this
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test-vnet/providers/Microsoft.Network/networkSecurityGroups/nsg-test-vnet"
  }
}

override_resource {
  target = azurerm_route_table.public
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test-vnet/providers/Microsoft.Network/routeTables/rt-test-vnet-public"
  }
}

override_resource {
  target = azurerm_route_table.private
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test-vnet/providers/Microsoft.Network/routeTables/rt-test-vnet-private"
  }
}

override_resource {
  target = azurerm_subnet_service_endpoint_storage_policy.this
  values = {
    id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test-vnet/providers/Microsoft.Network/serviceEndpointPolicies/sep-test-vnet"
  }
}

# Shared variables — overridden per-run as needed
variables {
  name               = "test-vnet"
  location           = "eastus2"
  vnet_address_space = ["10.0.0.0/16"]
  tags               = { environment = "test" }
}

# ═══════════════════════════════════════════════════════════════════════════════
# Subnet Classification
# ═══════════════════════════════════════════════════════════════════════════════

run "private_subnet_classification" {
  command = plan

  variables {
    subnets = {
      priv-app = ["10.0.1.0/24"]
      priv-db  = ["10.0.2.0/24"]
      data     = ["10.0.3.0/24"]
      services = ["10.0.4.0/24"]
    }
  }

  assert {
    condition     = output.subnet_configuration["priv-app"].is_public == false
    error_message = "priv-app should be private"
  }
  assert {
    condition     = output.subnet_configuration["priv-db"].is_public == false
    error_message = "priv-db should be private"
  }
  assert {
    condition     = output.subnet_configuration["data"].is_public == false
    error_message = "data should be private (no pub/appgw/gateway pattern)"
  }
  assert {
    condition     = output.subnet_configuration["services"].is_public == false
    error_message = "services should be private"
  }
  assert {
    condition     = length(output.private_subnet_ids) == 4
    error_message = "All 4 subnets should be private"
  }
  assert {
    condition     = length(output.public_subnet_ids) == 0
    error_message = "No subnets should be public"
  }
}

run "public_subnet_pub_pattern" {
  command = plan

  variables {
    subnets = {
      pub-web = ["10.0.1.0/24"]
      pub-api = ["10.0.2.0/24"]
    }
  }

  assert {
    condition     = output.subnet_configuration["pub-web"].is_public == true
    error_message = "pub-web should be public (matches 'pub' pattern)"
  }
  assert {
    condition     = output.subnet_configuration["pub-api"].is_public == true
    error_message = "pub-api should be public (matches 'pub' pattern)"
  }
  assert {
    condition     = length(output.public_subnet_ids) == 2
    error_message = "Both subnets should be public"
  }
}

run "public_subnet_appgw_pattern" {
  command = plan

  variables {
    subnets = {
      appgw      = ["10.0.1.0/24"]
      priv-app   = ["10.0.2.0/24"]
    }
  }

  assert {
    condition     = output.subnet_configuration["appgw"].is_public == true
    error_message = "appgw should be public (matches 'appgw' pattern)"
  }
  assert {
    condition     = output.subnet_configuration["priv-app"].is_public == false
    error_message = "priv-app should remain private"
  }
}

run "public_subnet_gateway_pattern" {
  command = plan

  variables {
    subnets = {
      gateway-public = ["10.0.1.0/24"]
      my-gateway     = ["10.0.2.0/24"]
    }
  }

  assert {
    condition     = output.subnet_configuration["gateway-public"].is_public == true
    error_message = "gateway-public should be public (matches 'gateway' pattern)"
  }
  assert {
    condition     = output.subnet_configuration["my-gateway"].is_public == true
    error_message = "my-gateway should be public (matches 'gateway' pattern)"
  }
}

run "gateway_subnet_classification" {
  command = plan

  variables {
    subnets = {
      GatewaySubnet = ["10.0.255.0/27"]
      priv-app      = ["10.0.1.0/24"]
      pub-web       = ["10.0.2.0/24"]
    }
  }

  # GatewaySubnet uses the exact Azure name, not prefixed
  assert {
    condition     = output.subnet_configuration["GatewaySubnet"].name == "GatewaySubnet"
    error_message = "GatewaySubnet must be named exactly 'GatewaySubnet', got '${output.subnet_configuration["GatewaySubnet"].name}'"
  }
  # GatewaySubnet is not classified as public
  assert {
    condition     = output.subnet_configuration["GatewaySubnet"].is_public == false
    error_message = "GatewaySubnet should not be classified as public"
  }
  # GatewaySubnet is classified as gateway
  assert {
    condition     = output.subnet_configuration["GatewaySubnet"].is_gateway == true
    error_message = "GatewaySubnet should have is_gateway = true"
  }
  # GatewaySubnet excluded from private_subnet_ids
  assert {
    condition     = !contains(keys(output.private_subnet_ids), "GatewaySubnet")
    error_message = "GatewaySubnet should not appear in private_subnet_ids"
  }
  # GatewaySubnet excluded from public_subnet_ids
  assert {
    condition     = !contains(keys(output.public_subnet_ids), "GatewaySubnet")
    error_message = "GatewaySubnet should not appear in public_subnet_ids"
  }
  # GatewaySubnet is in subnet_ids
  assert {
    condition     = contains(keys(output.subnet_ids), "GatewaySubnet")
    error_message = "GatewaySubnet should appear in subnet_ids"
  }
  # gateway_subnet_id output is populated
  assert {
    condition     = output.gateway_subnet_id != null
    error_message = "gateway_subnet_id should not be null when GatewaySubnet is defined"
  }
  # No NAT for GatewaySubnet
  assert {
    condition     = output.subnet_configuration["GatewaySubnet"].has_nat_gateway == false
    error_message = "GatewaySubnet should never get a NAT gateway"
  }
  # No service endpoints for GatewaySubnet
  assert {
    condition     = output.subnet_configuration["GatewaySubnet"].has_service_endpoints == false
    error_message = "GatewaySubnet should never get service endpoints"
  }
  # Other subnets still classified correctly
  assert {
    condition     = output.subnet_configuration["priv-app"].is_gateway == false
    error_message = "priv-app should not be flagged as gateway"
  }
  assert {
    condition     = length(output.private_subnet_ids) == 1
    error_message = "Only priv-app should be in private_subnet_ids"
  }
  assert {
    condition     = length(output.public_subnet_ids) == 1
    error_message = "Only pub-web should be in public_subnet_ids"
  }
}

run "gateway_subnet_id_null_when_absent" {
  command = plan

  variables {
    subnets = {
      priv-app = ["10.0.1.0/24"]
    }
  }

  assert {
    condition     = output.gateway_subnet_id == null
    error_message = "gateway_subnet_id should be null when GatewaySubnet is not defined"
  }
}

run "aks_subnets_are_private" {
  command = plan

  variables {
    subnets = {
      priv-aks-nodes = ["10.0.1.0/24"]
      priv-k8s-pod   = ["10.0.2.0/24"]
      priv-node-pool = ["10.0.3.0/24"]
      pod-network    = ["10.0.4.0/24"]
    }
  }

  assert {
    condition     = output.subnet_configuration["priv-aks-nodes"].is_public == false
    error_message = "AKS nodes subnet should be private"
  }
  assert {
    condition     = output.subnet_configuration["priv-k8s-pod"].is_public == false
    error_message = "k8s pod subnet should be private"
  }
  assert {
    condition     = output.subnet_configuration["priv-node-pool"].is_public == false
    error_message = "node pool subnet should be private"
  }
  assert {
    condition     = output.subnet_configuration["pod-network"].is_public == false
    error_message = "pod network subnet should be private"
  }
  assert {
    condition     = length(output.private_subnet_ids) == 4
    error_message = "All AKS subnets should be private"
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# Subnet Naming Convention
# ═══════════════════════════════════════════════════════════════════════════════

run "subnet_naming_convention" {
  command = plan

  variables {
    subnets = {
      priv-app = ["10.0.1.0/24"]
      pub-web  = ["10.0.2.0/24"]
      appgw    = ["10.0.3.0/24"]
    }
  }

  assert {
    condition     = output.subnet_configuration["priv-app"].name == "test-vnet-priv-app"
    error_message = "Expected 'test-vnet-priv-app', got '${output.subnet_configuration["priv-app"].name}'"
  }
  assert {
    condition     = output.subnet_configuration["pub-web"].name == "test-vnet-pub-web"
    error_message = "Expected 'test-vnet-pub-web', got '${output.subnet_configuration["pub-web"].name}'"
  }
  assert {
    condition     = output.subnet_configuration["appgw"].name == "test-vnet-appgw"
    error_message = "Expected 'test-vnet-appgw', got '${output.subnet_configuration["appgw"].name}'"
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# Resource Naming
# ═══════════════════════════════════════════════════════════════════════════════

run "resource_naming" {
  command = plan

  variables {
    subnets = { priv-app = ["10.0.1.0/24"] }
  }

  assert {
    condition     = output.resource_group_name == "rg-test-vnet"
    error_message = "Resource group should follow 'rg-<name>' convention"
  }
  assert {
    condition     = output.vnet_name == "test-vnet"
    error_message = "VNet name should match input name"
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# Address Prefixes
# ═══════════════════════════════════════════════════════════════════════════════

run "address_prefixes_passthrough" {
  command = plan

  variables {
    subnets = {
      priv-app = ["10.0.1.0/24"]
      priv-db  = ["10.0.2.0/24", "10.0.3.0/24"]
    }
  }

  assert {
    condition     = output.subnet_configuration["priv-app"].address_prefixes == tolist(["10.0.1.0/24"])
    error_message = "Single address prefix should pass through"
  }
  assert {
    condition     = output.subnet_configuration["priv-db"].address_prefixes == tolist(["10.0.2.0/24", "10.0.3.0/24"])
    error_message = "Multiple address prefixes should pass through"
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# Feature Toggles
# ═══════════════════════════════════════════════════════════════════════════════

run "all_defaults_with_mixed_subnets" {
  command = apply

  variables {
    subnets = {
      priv-app = ["10.0.1.0/24"]
      pub-web  = ["10.0.2.0/24"]
    }
  }

  # NAT gateway created by default when private subnets exist
  assert {
    condition     = output.nat_gateway_id != null
    error_message = "NAT gateway should be created when enabled and private subnets exist"
  }

  # NSG created by default
  assert {
    condition     = output.nsg_id != null
    error_message = "NSG should be created by default"
  }

  # Private subnet gets NAT gateway + service endpoints
  assert {
    condition     = output.subnet_configuration["priv-app"].has_nat_gateway == true
    error_message = "Private subnet should have NAT gateway by default"
  }
  assert {
    condition     = output.subnet_configuration["priv-app"].has_service_endpoints == true
    error_message = "Private subnet should have service endpoints by default"
  }

  # Public subnet does NOT get NAT gateway or service endpoints
  assert {
    condition     = output.subnet_configuration["pub-web"].has_nat_gateway == false
    error_message = "Public subnet should not have NAT gateway"
  }
  assert {
    condition     = output.subnet_configuration["pub-web"].has_service_endpoints == false
    error_message = "Public subnet should not have service endpoints"
  }
}

run "nat_gateway_disabled" {
  command = apply

  variables {
    subnets            = { priv-app = ["10.0.1.0/24"] }
    enable_nat_gateway = false
  }

  assert {
    condition     = output.nat_gateway_id == null
    error_message = "NAT gateway should not be created when disabled"
  }
  assert {
    condition     = output.subnet_configuration["priv-app"].has_nat_gateway == false
    error_message = "Private subnet should not report NAT gateway when toggle is off"
  }
}

run "nsg_disabled" {
  command = apply

  variables {
    subnets    = { priv-app = ["10.0.1.0/24"] }
    enable_nsg = false
  }

  assert {
    condition     = output.nsg_id == null
    error_message = "NSG should not be created when disabled"
  }
}

run "service_endpoints_disabled" {
  command = plan

  variables {
    subnets                  = { priv-app = ["10.0.1.0/24"] }
    enable_service_endpoints = false
  }

  assert {
    condition     = output.subnet_configuration["priv-app"].has_service_endpoints == false
    error_message = "Service endpoints should be disabled"
  }
}

run "public_only_no_nat_gateway" {
  command = apply

  variables {
    subnets = {
      pub-web = ["10.0.1.0/24"]
      appgw   = ["10.0.2.0/24"]
    }
  }

  assert {
    condition     = output.nat_gateway_id == null
    error_message = "NAT gateway should not be created when no private subnets exist"
  }
  assert {
    condition     = length(output.public_subnet_ids) == 2
    error_message = "Both subnets should be public"
  }
  assert {
    condition     = length(output.private_subnet_ids) == 0
    error_message = "Should have no private subnets"
  }
}

run "all_features_disabled" {
  command = apply

  variables {
    subnets = {
      priv-app = ["10.0.1.0/24"]
      pub-web  = ["10.0.2.0/24"]
    }
    enable_nat_gateway       = false
    enable_nsg               = false
    enable_route_table       = false
    enable_service_endpoints = false
  }

  assert {
    condition     = output.nat_gateway_id == null
    error_message = "NAT gateway should not be created"
  }
  assert {
    condition     = output.nsg_id == null
    error_message = "NSG should not be created"
  }
  assert {
    condition     = output.subnet_configuration["priv-app"].has_nat_gateway == false
    error_message = "Private subnet should not report NAT gateway"
  }
  assert {
    condition     = output.subnet_configuration["priv-app"].has_service_endpoints == false
    error_message = "Private subnet should not report service endpoints"
  }
  assert {
    condition     = output.subnet_configuration["pub-web"].has_nat_gateway == false
    error_message = "Public subnet should not report NAT gateway"
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# IPAM Key Merging
# ═══════════════════════════════════════════════════════════════════════════════

run "ipam_only_subnets" {
  command = plan

  variables {
    subnets = {}
    subnet_ipam_pools = {
      priv-app = [{
        pool_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Network/networkManagers/nm/ipamPools/pool1"
        prefix_length = 24
      }]
      priv-db = [{
        pool_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Network/networkManagers/nm/ipamPools/pool2"
        prefix_length = 24
      }]
    }
  }

  assert {
    condition     = length(output.subnet_ids) == 2
    error_message = "Should have 2 IPAM-only subnets"
  }
  assert {
    condition     = contains(keys(output.subnet_ids), "priv-app")
    error_message = "priv-app should exist from IPAM pool"
  }
  assert {
    condition     = contains(keys(output.subnet_ids), "priv-db")
    error_message = "priv-db should exist from IPAM pool"
  }
  # IPAM-only subnets have empty static address_prefixes
  assert {
    condition     = length(output.subnet_configuration["priv-app"].address_prefixes) == 0
    error_message = "IPAM-only subnet should have empty static address_prefixes"
  }
}

run "ipam_and_static_merged" {
  command = plan

  variables {
    subnets = {
      priv-app = ["10.0.1.0/24"]
      priv-db  = ["10.0.2.0/24"]
    }
    subnet_ipam_pools = {
      priv-svc = [{
        pool_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Network/networkManagers/nm/ipamPools/pool1"
        prefix_length = 24
      }]
    }
  }

  assert {
    condition     = length(output.subnet_ids) == 3
    error_message = "Should have 3 subnets (2 static + 1 IPAM)"
  }
  assert {
    condition     = contains(keys(output.subnet_ids), "priv-app")
    error_message = "Static subnet priv-app should exist"
  }
  assert {
    condition     = contains(keys(output.subnet_ids), "priv-svc")
    error_message = "IPAM subnet priv-svc should exist"
  }
  # Static subnet retains its address prefix
  assert {
    condition     = output.subnet_configuration["priv-app"].address_prefixes == tolist(["10.0.1.0/24"])
    error_message = "Static subnet should retain its address prefix"
  }
  # IPAM subnet has no static prefix
  assert {
    condition     = length(output.subnet_configuration["priv-svc"].address_prefixes) == 0
    error_message = "IPAM-only subnet should have empty static address_prefixes"
  }
}

run "ipam_key_overlap_deduplicates" {
  command = plan

  variables {
    subnets = {
      priv-app = ["10.0.1.0/24"]
    }
    subnet_ipam_pools = {
      priv-app = [{
        pool_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Network/networkManagers/nm/ipamPools/pool1"
        prefix_length = 24
      }]
    }
  }

  # Key exists in both — deduplicated to exactly 1 subnet
  assert {
    condition     = length(output.subnet_ids) == 1
    error_message = "Overlapping IPAM/static key should produce exactly 1 subnet"
  }
  assert {
    condition     = contains(keys(output.subnet_ids), "priv-app")
    error_message = "priv-app should exist"
  }
}

run "ipam_subnet_classification" {
  command = plan

  variables {
    subnets = {}
    subnet_ipam_pools = {
      pub-web = [{
        pool_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Network/networkManagers/nm/ipamPools/pool1"
        prefix_length = 24
      }]
      priv-aks-nodes = [{
        pool_id       = "/subscriptions/00000000-0000-0000-0000-000000000000/providers/Microsoft.Network/networkManagers/nm/ipamPools/pool2"
        prefix_length = 24
      }]
    }
  }

  # IPAM subnets follow the same classification rules
  assert {
    condition     = output.subnet_configuration["pub-web"].is_public == true
    error_message = "IPAM subnet pub-web should be classified as public"
  }
  assert {
    condition     = output.subnet_configuration["priv-aks-nodes"].is_public == false
    error_message = "IPAM subnet priv-aks-nodes should be classified as private"
  }
  assert {
    condition     = length(output.public_subnet_ids) == 1
    error_message = "Should have 1 public IPAM subnet"
  }
  assert {
    condition     = length(output.private_subnet_ids) == 1
    error_message = "Should have 1 private IPAM subnet"
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# Subnet Count Scenarios
# ═══════════════════════════════════════════════════════════════════════════════

run "single_subnet" {
  command = plan

  variables {
    subnets = { priv-app = ["10.0.1.0/24"] }
  }

  assert {
    condition     = length(output.subnet_ids) == 1
    error_message = "Should have exactly 1 subnet"
  }
  assert {
    condition     = length(output.private_subnet_ids) == 1
    error_message = "Should have exactly 1 private subnet"
  }
  assert {
    condition     = length(output.public_subnet_ids) == 0
    error_message = "Should have no public subnets"
  }
}

run "many_subnets_mixed" {
  command = plan

  variables {
    subnets = {
      priv-app       = ["10.0.1.0/24"]
      priv-db        = ["10.0.2.0/24"]
      priv-cache     = ["10.0.3.0/24"]
      priv-aks-nodes = ["10.0.4.0/24"]
      pub-web        = ["10.0.5.0/24"]
      pub-api        = ["10.0.6.0/24"]
      appgw          = ["10.0.7.0/24"]
    }
  }

  assert {
    condition     = length(output.subnet_ids) == 7
    error_message = "Should have 7 total subnets"
  }
  assert {
    condition     = length(output.private_subnet_ids) == 4
    error_message = "Should have 4 private subnets (priv-app, priv-db, priv-cache, priv-aks-nodes)"
  }
  assert {
    condition     = length(output.public_subnet_ids) == 3
    error_message = "Should have 3 public subnets (pub-web, pub-api, appgw)"
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# Variable Validation
# ═══════════════════════════════════════════════════════════════════════════════

run "invalid_pe_network_policy_rejected" {
  command = plan

  variables {
    subnets                           = { priv-app = ["10.0.1.0/24"] }
    private_endpoint_network_policies = "InvalidValue"
  }

  expect_failures = [
    var.private_endpoint_network_policies,
  ]
}

run "valid_pe_policy_enabled" {
  command = plan

  variables {
    subnets                           = { priv-app = ["10.0.1.0/24"] }
    private_endpoint_network_policies = "Enabled"
  }

  assert {
    condition     = length(output.subnet_ids) == 1
    error_message = "Enabled should be a valid PE policy"
  }
}

run "valid_pe_policy_disabled" {
  command = plan

  variables {
    subnets                           = { priv-app = ["10.0.1.0/24"] }
    private_endpoint_network_policies = "Disabled"
  }

  assert {
    condition     = length(output.subnet_ids) == 1
    error_message = "Disabled should be a valid PE policy"
  }
}

run "valid_pe_policy_nsg_only" {
  command = plan

  variables {
    subnets                           = { priv-app = ["10.0.1.0/24"] }
    private_endpoint_network_policies = "NetworkSecurityGroupEnabled"
  }

  assert {
    condition     = length(output.subnet_ids) == 1
    error_message = "NetworkSecurityGroupEnabled should be a valid PE policy"
  }
}

run "valid_pe_policy_rt_only" {
  command = plan

  variables {
    subnets                           = { priv-app = ["10.0.1.0/24"] }
    private_endpoint_network_policies = "RouteTableEnabled"
  }

  assert {
    condition     = length(output.subnet_ids) == 1
    error_message = "RouteTableEnabled should be a valid PE policy"
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# Peering
# ═══════════════════════════════════════════════════════════════════════════════

run "no_peerings_by_default" {
  command = plan

  variables {
    subnets = { priv-app = ["10.0.1.0/24"] }
  }

  assert {
    condition     = length(output.peering_ids) == 0
    error_message = "No peerings should be created when var.peerings is empty"
  }

  assert {
    condition     = length(output.peering_reverse_ids) == 0
    error_message = "No reverse peerings should be created when var.peerings is empty"
  }
}

run "single_peering_creates_output" {
  command = plan

  variables {
    subnets = { priv-app = ["10.0.1.0/24"] }
    peerings = {
      to-hub = {
        remote_virtual_network_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub/providers/Microsoft.Network/virtualNetworks/vnet-hub"
      }
    }
  }

  assert {
    condition     = length(output.peering_ids) == 1
    error_message = "One peering should produce one output entry"
  }

  assert {
    condition     = contains(keys(output.peering_ids), "to-hub")
    error_message = "Peering output key should match input key"
  }
}

run "multiple_peerings" {
  command = plan

  variables {
    subnets = { priv-app = ["10.0.1.0/24"] }
    peerings = {
      to-hub = {
        remote_virtual_network_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub/providers/Microsoft.Network/virtualNetworks/vnet-hub"
      }
      to-shared = {
        remote_virtual_network_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-shared/providers/Microsoft.Network/virtualNetworks/vnet-shared"
      }
    }
  }

  assert {
    condition     = length(output.peering_ids) == 2
    error_message = "Two peering entries should produce two output entries"
  }
}

run "peering_with_all_forward_options" {
  command = plan

  variables {
    subnets = { priv-app = ["10.0.1.0/24"] }
    peerings = {
      to-hub = {
        remote_virtual_network_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub/providers/Microsoft.Network/virtualNetworks/vnet-hub"
        allow_forwarded_traffic            = true
        allow_gateway_transit              = true
        allow_virtual_network_access       = true
        do_not_verify_remote_gateways      = true
        enable_only_ipv6_peering           = false
        use_remote_gateways                = false
        peer_complete_vnets                = true
      }
    }
  }

  assert {
    condition     = length(output.peering_ids) == 1
    error_message = "Peering with all forward options should plan successfully"
  }
}

run "peering_with_reverse" {
  command = plan

  variables {
    subnets = { priv-app = ["10.0.1.0/24"] }
    peerings = {
      to-hub = {
        remote_virtual_network_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub/providers/Microsoft.Network/virtualNetworks/vnet-hub"
        allow_forwarded_traffic            = true
        create_reverse_peering             = true
        reverse_name                       = "peer-hub-to-spoke"
      }
    }
  }

  assert {
    condition     = length(output.peering_ids) == 1
    error_message = "Forward peering should be created"
  }

  assert {
    condition     = length(output.peering_reverse_ids) == 1
    error_message = "Reverse peering output should be present"
  }
}

run "peering_reverse_mirrors_forward_defaults" {
  command = plan

  variables {
    subnets = { priv-app = ["10.0.1.0/24"] }
    peerings = {
      to-hub = {
        remote_virtual_network_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub/providers/Microsoft.Network/virtualNetworks/vnet-hub"
        allow_forwarded_traffic            = true
        allow_gateway_transit              = true
        create_reverse_peering             = true
        reverse_name                       = "peer-hub-to-spoke"
        # reverse_allow_forwarded_traffic and reverse_allow_gateway_transit
        # are null — should mirror forward values in the submodule
      }
    }
  }

  assert {
    condition     = length(output.peering_ids) == 1
    error_message = "Peering with mirror-forward defaults should plan successfully"
  }
}

run "peering_address_space_scoped" {
  command = plan

  variables {
    subnets = { priv-app = ["10.0.1.0/24"] }
    peerings = {
      to-shared = {
        remote_virtual_network_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-shared/providers/Microsoft.Network/virtualNetworks/vnet-shared"
        peer_complete_vnets                = false
        local_peered_address_spaces        = [{ address_prefix = "10.0.1.0/24" }]
        remote_peered_address_spaces       = [{ address_prefix = "10.1.0.0/24" }]
        create_reverse_peering             = true
        reverse_name                       = "peer-shared-to-app"
      }
    }
  }

  assert {
    condition     = length(output.peering_ids) == 1
    error_message = "Address-space scoped peering should plan successfully"
  }
}

run "peering_subnet_scoped" {
  command = plan

  variables {
    subnets = { priv-app = ["10.0.1.0/24"] }
    peerings = {
      to-data = {
        remote_virtual_network_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-data/providers/Microsoft.Network/virtualNetworks/vnet-data"
        peer_complete_vnets                = false
        local_peered_subnets               = [{ subnet_name = "priv-app" }]
        remote_peered_subnets              = [{ subnet_name = "priv-db" }]
        create_reverse_peering             = true
        reverse_name                       = "peer-data-to-app"
      }
    }
  }

  assert {
    condition     = length(output.peering_ids) == 1
    error_message = "Subnet-scoped peering should plan successfully"
  }
}

run "peering_with_sync_enabled" {
  command = plan

  variables {
    subnets = { priv-app = ["10.0.1.0/24"] }
    peerings = {
      to-hub = {
        remote_virtual_network_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub/providers/Microsoft.Network/virtualNetworks/vnet-hub"
        create_reverse_peering             = true
        reverse_name                       = "peer-hub-to-spoke"
        sync_remote_address_space_enabled  = true
        sync_remote_address_space_triggers = "v1"
      }
    }
  }

  assert {
    condition     = length(output.peering_ids) == 1
    error_message = "Peering with sync should plan successfully"
  }
}

run "peering_forward_only_no_reverse_output" {
  command = plan

  variables {
    subnets = { priv-app = ["10.0.1.0/24"] }
    peerings = {
      to-hub = {
        remote_virtual_network_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-hub/providers/Microsoft.Network/virtualNetworks/vnet-hub"
      }
    }
  }

  assert {
    condition     = output.peering_reverse_ids["to-hub"] == null
    error_message = "Forward-only peering should have null reverse ID"
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# VPN Gateway
# ═══════════════════════════════════════════════════════════════════════════════

run "vpn_disabled_by_default" {
  command = plan

  variables {
    subnets = { priv-app = ["10.0.1.0/24"] }
  }

  assert {
    condition     = output.vpn_gateway_id == null
    error_message = "VPN gateway ID should be null when VPN is disabled"
  }
  assert {
    condition     = output.vpn_gateway_public_ip == null
    error_message = "VPN public IP should be null when VPN is disabled"
  }
  assert {
    condition     = output.vpn_connection_ids == {}
    error_message = "VPN connection IDs should be empty when VPN is disabled"
  }
  assert {
    condition     = output.vpn_local_network_gateway_ids == {}
    error_message = "VPN local gateway IDs should be empty when VPN is disabled"
  }
}

run "vpn_enabled_creates_gateway" {
  command = plan

  variables {
    subnets = {
      GatewaySubnet = ["10.0.255.0/27"]
      priv-app      = ["10.0.1.0/24"]
    }
    enable_vpn_gateway = true
  }

  assert {
    condition     = output.vpn_gateway_id != null
    error_message = "VPN gateway ID should be set when VPN is enabled"
  }
  assert {
    condition     = output.vpn_gateway_public_ip != null
    error_message = "VPN gateway should have a public IP"
  }
  assert {
    condition     = output.gateway_subnet_id != null
    error_message = "GatewaySubnet must exist when VPN is enabled"
  }
}

run "vpn_with_single_connection" {
  command = plan

  variables {
    subnets = {
      GatewaySubnet = ["10.0.255.0/27"]
      priv-app      = ["10.0.1.0/24"]
    }
    enable_vpn_gateway = true
    vpn_connections = {
      to-aws = {
        peer_ip_address = "203.0.113.1"
        shared_key      = "SuperSecret123!"
        address_space   = ["10.200.0.0/16", "172.16.0.0/12"]
      }
    }
  }

  # Gateway created (connection counts are internal to the overridden submodule)
  assert {
    condition     = output.vpn_gateway_id != null
    error_message = "VPN gateway should be created with a single connection"
  }
  assert {
    condition     = output.vpn_gateway_public_ip != null
    error_message = "VPN gateway should have a public IP"
  }
}

run "vpn_with_multiple_connections" {
  command = plan

  variables {
    subnets = {
      GatewaySubnet = ["10.0.255.0/27"]
      priv-app      = ["10.0.1.0/24"]
    }
    enable_vpn_gateway = true
    vpn_connections = {
      to-aws-primary = {
        peer_ip_address = "203.0.113.1"
        shared_key      = "PrimarySecret!"
        address_space   = ["10.200.0.0/16"]
      }
      to-aws-secondary = {
        peer_ip_address = "203.0.113.2"
        shared_key      = "SecondarySecret!"
        address_space   = ["10.200.0.0/16"]
      }
      to-datacenter = {
        peer_ip_address = "198.51.100.1"
        shared_key      = "DCSecret!"
        address_space   = ["192.168.0.0/16"]
      }
    }
  }

  # Validates that multi-connection map is accepted (connection counts
  # are internal to the overridden VPN submodule and can't be asserted)
  assert {
    condition     = output.vpn_gateway_id != null
    error_message = "VPN gateway should be created with multiple connections"
  }
}

run "vpn_bgp_settings" {
  command = plan

  variables {
    subnets = {
      GatewaySubnet = ["10.0.255.0/27"]
      priv-app      = ["10.0.1.0/24"]
    }
    enable_vpn_gateway     = true
    vpn_gateway_enable_bgp = true
    vpn_gateway_bgp_asn    = 65100
    vpn_connections = {
      to-aws = {
        peer_ip_address     = "203.0.113.1"
        shared_key          = "BGPSecret!"
        enable_bgp          = true
        bgp_asn             = 64512
        bgp_peering_address = "169.254.21.1"
      }
    }
  }

  assert {
    condition     = output.vpn_gateway_id != null
    error_message = "VPN gateway with BGP should be created"
  }
}

run "vpn_with_ipsec_policy" {
  command = plan

  variables {
    subnets = {
      GatewaySubnet = ["10.0.255.0/27"]
      priv-app      = ["10.0.1.0/24"]
    }
    enable_vpn_gateway = true
    vpn_connections = {
      to-aws = {
        peer_ip_address = "203.0.113.1"
        shared_key      = "IPsecSecret!"
        address_space   = ["10.200.0.0/16"]
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
    }
  }

  assert {
    condition     = output.vpn_gateway_id != null
    error_message = "VPN gateway with custom IPsec policy should be created"
  }
}

run "vpn_secondary_ip_null_when_not_active_active" {
  command = plan

  variables {
    subnets = {
      GatewaySubnet = ["10.0.255.0/27"]
      priv-app      = ["10.0.1.0/24"]
    }
    enable_vpn_gateway         = true
    vpn_gateway_active_active  = false
  }

  assert {
    condition     = output.vpn_gateway_secondary_public_ip == null
    error_message = "Secondary public IP should be null when active-active is disabled"
  }
}

run "vpn_disabled_outputs_empty_maps" {
  command = plan

  variables {
    subnets = {
      GatewaySubnet = ["10.0.255.0/27"]
      priv-app      = ["10.0.1.0/24"]
    }
    enable_vpn_gateway = false
  }

  assert {
    condition     = output.vpn_gateway_id == null
    error_message = "VPN gateway ID should be null when disabled even with GatewaySubnet present"
  }
  assert {
    condition     = output.vpn_connection_ids == {}
    error_message = "Connection IDs map should be empty when VPN disabled"
  }
  assert {
    condition     = output.vpn_local_network_gateway_ids == {}
    error_message = "Local gateway IDs map should be empty when VPN disabled"
  }
}
