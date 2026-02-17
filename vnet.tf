module "vnet" {
  source = "./modules/vnet"

  location      = azurerm_resource_group.this.location
  parent_id     = azurerm_resource_group.this.id
  address_space = var.vnet_address_space
  ipam_pools    = var.ipam_pools
  name          = var.name
  tags          = var.tags
}
