# ─── Gateway ─────────────────────────────────────────────────────────────────

output gateway_id {
  description = "VPN Gateway resource ID"
  value       = azurerm_virtual_network_gateway.this.id
}

output gateway_name {
  description = "VPN Gateway name"
  value       = azurerm_virtual_network_gateway.this.name
}

output gateway_public_ip {
  description = "Primary public IP address of the VPN gateway"
  value       = azurerm_public_ip.primary.ip_address
}

output gateway_public_ip_id {
  description = "Primary public IP resource ID"
  value       = azurerm_public_ip.primary.id
}

output gateway_secondary_public_ip {
  description = "Secondary public IP address (active-active only, null otherwise)"
  value       = try(azurerm_public_ip.secondary[0].ip_address, null)
}

output gateway_bgp_settings {
  description = "BGP settings of the VPN gateway (null if BGP disabled)"
  value       = var.enable_bgp ? azurerm_virtual_network_gateway.this.bgp_settings : null
}

# ─── Connections ─────────────────────────────────────────────────────────────

output connection_ids {
  description = "Map of connection key → VPN connection resource ID"
  value = {
    for k, v in azurerm_virtual_network_gateway_connection.this : k => v.id
  }
}

output local_network_gateway_ids {
  description = "Map of connection key → Local Network Gateway resource ID"
  value = {
    for k, v in azurerm_local_network_gateway.this : k => v.id
  }
}
