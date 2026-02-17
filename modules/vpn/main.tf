# ═══════════════════════════════════════════════════════════════════════════════
# VPN Gateway + Connections — creates the gateway, public IP(s),
# local network gateways, and IPsec connections.
# ═══════════════════════════════════════════════════════════════════════════════

# ─── Public IP(s) for VPN Gateway ────────────────────────────────────────────

resource "azurerm_public_ip" "primary" {
  name                = "pip-vpngw-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_public_ip" "secondary" {
  count = var.active_active ? 1 : 0

  name                = "pip-vpngw-${var.name}-secondary"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

# ─── VPN Gateway ─────────────────────────────────────────────────────────────

resource "azurerm_virtual_network_gateway" "this" {
  name                = "vpngw-${var.name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  type                = "Vpn"
  vpn_type            = var.vpn_type
  sku                 = var.sku
  generation          = var.generation
  active_active       = var.active_active
  enable_bgp          = var.enable_bgp

  dynamic "bgp_settings" {
    for_each = var.enable_bgp ? [1] : []
    content {
      asn = var.bgp_asn
    }
  }

  ip_configuration {
    name                          = "primary"
    public_ip_address_id          = azurerm_public_ip.primary.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = var.gateway_subnet_id
  }

  dynamic "ip_configuration" {
    for_each = var.active_active ? [1] : []
    content {
      name                          = "secondary"
      public_ip_address_id          = azurerm_public_ip.secondary[0].id
      private_ip_address_allocation = "Dynamic"
      subnet_id                     = var.gateway_subnet_id
    }
  }

  tags = var.tags
}

# ─── Local Network Gateways (one per connection — represents remote site) ──

resource "azurerm_local_network_gateway" "this" {
  for_each = var.vpn_connections

  name                = "lgw-${each.key}"
  location            = var.location
  resource_group_name = var.resource_group_name
  gateway_address     = each.value.peer_ip_address
  address_space       = each.value.enable_bgp ? [] : each.value.address_space

  dynamic "bgp_settings" {
    for_each = each.value.enable_bgp && each.value.bgp_asn != null ? [1] : []
    content {
      asn                 = each.value.bgp_asn
      bgp_peering_address = each.value.bgp_peering_address
    }
  }

  tags = merge(var.tags, each.value.tags)
}

# ─── VPN Connections (one per entry in vpn_connections) ──────────────────────

resource "azurerm_virtual_network_gateway_connection" "this" {
  for_each = var.vpn_connections

  name                       = "vpn-${each.key}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.this.id
  local_network_gateway_id   = azurerm_local_network_gateway.this[each.key].id
  shared_key                 = each.value.shared_key
  enable_bgp                 = each.value.enable_bgp
  connection_protocol        = each.value.connection_protocol
  dpd_timeout_seconds        = each.value.dpd_timeout_seconds
  routing_weight             = each.value.routing_weight

  use_policy_based_traffic_selectors = each.value.use_policy_based_traffic_selectors

  dynamic "ipsec_policy" {
    for_each = each.value.ipsec_policy != null ? [each.value.ipsec_policy] : []
    content {
      ike_encryption   = ipsec_policy.value.ike_encryption
      ike_integrity    = ipsec_policy.value.ike_integrity
      dh_group         = ipsec_policy.value.dh_group
      ipsec_encryption = ipsec_policy.value.ipsec_encryption
      ipsec_integrity  = ipsec_policy.value.ipsec_integrity
      pfs_group        = ipsec_policy.value.pfs_group
      sa_lifetime      = ipsec_policy.value.sa_lifetime
      sa_datasize      = ipsec_policy.value.sa_datasize != null ? ipsec_policy.value.sa_datasize : null
    }
  }

  tags = merge(var.tags, each.value.tags)
}
