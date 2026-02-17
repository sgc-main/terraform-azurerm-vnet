output vnet_id {
  description = "Virtual Network ID"
  value       = module.vnet.resource_id
}

output vnet_name {
  description = "Virtual Network name"
  value       = module.vnet.name
}

output vnet_address_spaces {
  description = "Virtual Network address spaces"
  value       = module.vnet.address_spaces
}

output subnet_ids {
  description = "Map of subnet keys to their resource IDs"
  value = {
    for k, v in module.subnet : k => v.resource_id
  }
}

output public_subnet_ids {
  description = "Map of public subnet IDs"
  value = {
    for k, v in local.public_subnets : k => module.subnet[k].resource_id
  }
}

output private_subnet_ids {
  description = "Map of private subnet IDs"
  value = {
    for k, v in local.private_subnets : k => module.subnet[k].resource_id
  }
}

output gateway_subnet_id {
  description = "GatewaySubnet resource ID (null if not defined)"
  value       = try(module.subnet["GatewaySubnet"].resource_id, null)
}

output resource_group_name {
  description = "Resource group name"
  value       = azurerm_resource_group.this.name
}

output resource_group_id {
  description = "Resource group ID"
  value       = azurerm_resource_group.this.id
}

output nat_gateway_id {
  description = "NAT Gateway ID (if enabled)"
  value       = try(azurerm_nat_gateway.this[0].id, null)
}

output nsg_id {
  description = "Network Security Group ID (if enabled)"
  value       = try(azurerm_network_security_group.this[0].id, null)
}

output log_analytics_workspace_id {
  description = "Log Analytics Workspace ID (null if disabled)"
  value       = try(azurerm_log_analytics_workspace.this[0].id, null)
}

output user_assigned_identity_id {
  description = "User Assigned Identity ID (null if disabled)"
  value       = try(azurerm_user_assigned_identity.this[0].id, null)
}

output user_assigned_identity_principal_id {
  description = "User Assigned Identity Principal ID (null if disabled)"
  value       = try(azurerm_user_assigned_identity.this[0].principal_id, null)
}

output subnet_configuration {
  description = "Computed subnet configuration showing public/private designation"
  value = {
    for k, v in local.subnets_config : k => {
      name                  = v.name
      address_prefixes      = v.address_prefixes
      is_public             = v.is_public
      is_gateway            = v.is_gateway
      has_nat_gateway       = !v.is_public && !v.is_gateway && var.enable_nat_gateway
      has_service_endpoints = !v.is_public && !v.is_gateway && var.enable_service_endpoints
    }
  }
}

# --- Peering Outputs ---

output peering_ids {
  description = "Map of peering keys to their forward peering resource IDs"
  value = {
    for k, v in module.peering : k => v.resource_id
  }
}

output peering_reverse_ids {
  description = "Map of peering keys to their reverse peering resource IDs (null if reverse not created)"
  value = {
    for k, v in module.peering : k => v.reverse_resource_id
  }
}

# --- VPN Gateway Outputs ---

output vpn_gateway_id {
  description = "VPN Gateway resource ID (null if VPN disabled)"
  value       = try(module.vpn[0].gateway_id, null)
}

output vpn_gateway_public_ip {
  description = "Primary public IP of the VPN gateway (null if VPN disabled)"
  value       = try(module.vpn[0].gateway_public_ip, null)
}

output vpn_gateway_secondary_public_ip {
  description = "Secondary public IP of the VPN gateway (active-active only, null otherwise)"
  value       = try(module.vpn[0].gateway_secondary_public_ip, null)
}

output vpn_gateway_bgp_settings {
  description = "BGP settings of the VPN gateway (null if VPN or BGP disabled)"
  value       = try(module.vpn[0].gateway_bgp_settings, null)
}

output vpn_connection_ids {
  description = "Map of connection key → VPN connection resource ID"
  value       = try(module.vpn[0].connection_ids, {})
}

output vpn_local_network_gateway_ids {
  description = "Map of connection key → Local Network Gateway resource ID"
  value       = try(module.vpn[0].local_network_gateway_ids, {})
}
