module "vpn" {
  count  = var.enable_vpn_gateway ? 1 : 0
  source = "./modules/vpn"

  name                = var.name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  gateway_subnet_id   = module.subnet["GatewaySubnet"].resource_id

  # Gateway settings
  sku         = var.vpn_gateway_sku
  generation  = var.vpn_gateway_generation
  vpn_type    = var.vpn_gateway_type
  active_active = var.vpn_gateway_active_active
  enable_bgp  = var.vpn_gateway_enable_bgp
  bgp_asn     = var.vpn_gateway_bgp_asn

  # Connections
  vpn_connections = var.vpn_connections

  tags = var.tags

  depends_on = [module.subnet]
}
