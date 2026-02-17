module "subnet" {
  source   = "./modules/subnet"
  for_each = local.subnets_config

  name                            = each.value.name
  parent_id                       = module.vnet.resource_id
  address_prefixes                = lookup(var.subnet_ipam_pools, each.key, null) != null ? null : each.value.address_prefixes
  ipam_pools                      = lookup(var.subnet_ipam_pools, each.key, null)
  default_outbound_access_enabled = each.value.is_public

  # NAT Gateway — private subnets only (not App Gateway, not GatewaySubnet)
  nat_gateway = (
    !each.value.is_public && !each.value.is_app_gateway && !each.value.is_gateway && var.enable_nat_gateway && length(azurerm_nat_gateway.this) > 0
    ? { id = azurerm_nat_gateway.this[0].id }
    : null
  )

  # NSG — all subnets except GatewaySubnet (Azure disallows NSG on GatewaySubnet)
  network_security_group = (
    !each.value.is_gateway && var.enable_nsg && length(azurerm_network_security_group.this) > 0
    ? { id = azurerm_network_security_group.this[0].id }
    : null
  )

  # Route table — public get public RT, private get private RT, GatewaySubnet gets none
  route_table = (
    !each.value.is_gateway && var.enable_route_table
    ? (
      each.value.is_public && length(azurerm_route_table.public) > 0
      ? { id = azurerm_route_table.public[0].id }
      : !each.value.is_public && length(azurerm_route_table.private) > 0
      ? { id = azurerm_route_table.private[0].id }
      : null
    )
    : null
  )

  # Service endpoints — private subnets only, not GatewaySubnet, AKS gets extended set
  service_endpoints_with_location = (
    !each.value.is_public && !each.value.is_gateway && var.enable_service_endpoints
    ? [
      for svc in (each.value.is_aks ? local.aks_service_endpoints : local.default_service_endpoints) : {
        service   = svc
        locations = [azurerm_resource_group.this.location]
      }
    ]
    : []
  )

  # Service endpoint policies — wire storage policy to private non-AKS subnets, not GatewaySubnet
  service_endpoint_policies = (
    !each.value.is_public && !each.value.is_aks && !each.value.is_gateway && var.enable_service_endpoints && length(azurerm_subnet_service_endpoint_storage_policy.this) > 0
    ? { storage = { id = azurerm_subnet_service_endpoint_storage_policy.this[0].id } }
    : {}
  )

  # Private endpoint network policies — caller-controlled for private subnets, disabled for public
  private_endpoint_network_policies = !each.value.is_public ? var.private_endpoint_network_policies : "Disabled"

  # Private link service — opt-in via var.private_link_subnets (disables NSG/UDR on PLS traffic)
  private_link_service_network_policies_enabled = contains(var.private_link_subnets, each.key) ? false : true

  # Delegations — from merged auto-detect + explicit overrides (GatewaySubnet cannot have delegations)
  delegations = each.value.is_gateway ? [] : lookup(local.subnet_delegations, each.key, [])
}
