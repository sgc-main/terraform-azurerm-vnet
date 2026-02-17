locals {
  # Merge subnet keys from both var.subnets and var.subnet_ipam_pools
  all_subnet_keys = toset(concat(keys(var.subnets), keys(var.subnet_ipam_pools)))

  # Dynamically compute subnet configurations
  subnets_config = {
    for subnet_key in local.all_subnet_keys : subnet_key => {
      name             = lower(subnet_key) == "gatewaysubnet" ? "GatewaySubnet" : "${var.name}-${subnet_key}"
      address_prefixes = lookup(var.subnets, subnet_key, [])
      is_gateway       = lower(subnet_key) == "gatewaysubnet"
      is_public        = lower(subnet_key) != "gatewaysubnet" && can(regex("pub|appgw|gateway", lower(subnet_key)))
      is_aks           = can(regex("aks|node|k8s|pod", lower(subnet_key)))
      is_app_gateway   = lower(subnet_key) != "gatewaysubnet" && can(regex("appgw|gateway|agc", lower(subnet_key)))
    }
  }

  # Compute which subnets need NAT Gateway (private subnets only, excludes GatewaySubnet)
  private_subnets = {
    for k, v in local.subnets_config : k => v if !v.is_public && !v.is_gateway
  }

  # Compute which subnets are public (excludes GatewaySubnet)
  public_subnets = {
    for k, v in local.subnets_config : k => v if v.is_public
  }

  # AKS subnets need specific service endpoints (baseline + extras)
  aks_service_endpoints = distinct(concat(
    ["Microsoft.ContainerRegistry", "Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.Sql"],
    var.extra_aks_service_endpoints
  ))

  # Default service endpoints for private non-AKS subnets (baseline + extras)
  default_service_endpoints = distinct(concat(
    ["Microsoft.Storage", "Microsoft.KeyVault"],
    var.extra_service_endpoints
  ))

  # Auto-detect delegations from subnet key patterns (can be overridden via var.subnet_delegations)
  auto_delegations = merge(
    # Application Gateway delegation
    var.enable_app_gateway_delegation ? {
      for k, v in local.subnets_config : k => [{
        name = "Microsoft.Network.applicationGateways"
        service_delegation = {
          name = "Microsoft.Network/applicationGateways"
        }
      }] if v.is_app_gateway
    } : {},
    # Web/serverFarms delegation — exclude app gateway and AKS subnets
    var.enable_web_delegation ? {
      for k, v in local.subnets_config : k => [{
        name = "Microsoft.Web.serverFarms"
        service_delegation = {
          name = "Microsoft.Web/serverFarms"
        }
      }] if can(regex("func|web", lower(k))) && !v.is_aks && !v.is_app_gateway
    } : {}
  )

  # Merge auto-detected delegations with explicit overrides (explicit wins)
  subnet_delegations = merge(local.auto_delegations, var.subnet_delegations)
}
