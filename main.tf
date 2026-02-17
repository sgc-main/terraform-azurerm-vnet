resource "azurerm_resource_group" "this" {
  name     = "rg-${var.name}"
  location = var.location
  tags     = var.tags
}

# Creating a NAT Gateway for private subnets
resource "azurerm_nat_gateway" "this" {
  count               = var.enable_nat_gateway && length(local.private_subnets) > 0 ? 1 : 0
  location            = azurerm_resource_group.this.location
  name                = "ngw-${var.name}"
  resource_group_name = azurerm_resource_group.this.name
  sku_name            = "Standard"
  tags                = var.tags
}

resource "azurerm_network_security_group" "this" {
  count               = var.enable_nsg ? 1 : 0
  location            = azurerm_resource_group.this.location
  name                = "nsg-${var.name}"
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_network_security_rule" "this" {
  for_each = var.enable_nsg ? var.nsg_rules : {}

  name                         = each.key
  priority                     = each.value.priority
  direction                    = each.value.direction
  access                       = each.value.access
  protocol                     = each.value.protocol
  source_port_range            = each.value.source_port_range
  destination_port_range       = each.value.destination_port_range
  source_port_ranges           = each.value.source_port_ranges
  destination_port_ranges      = each.value.destination_port_ranges
  source_address_prefix        = each.value.source_address_prefix
  destination_address_prefix   = each.value.destination_address_prefix
  source_address_prefixes      = each.value.source_address_prefixes
  destination_address_prefixes = each.value.destination_address_prefixes
  description                  = each.value.description
  resource_group_name          = azurerm_resource_group.this.name
  network_security_group_name  = azurerm_network_security_group.this[0].name
}

resource "azurerm_route_table" "public" {
  count               = var.enable_route_table && length(local.public_subnets) > 0 ? 1 : 0
  location            = azurerm_resource_group.this.location
  name                = "rt-${var.name}-public"
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_route_table" "private" {
  count               = var.enable_route_table && length(local.private_subnets) > 0 ? 1 : 0
  location            = azurerm_resource_group.this.location
  name                = "rt-${var.name}-private"
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags

  dynamic "route" {
    for_each = var.use_azure_firewall ? [1] : []
    content {
      name                   = "to-azure-firewall"
      address_prefix         = "0.0.0.0/0"
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = var.azure_firewall_private_ip
    }
  }
}

resource "azurerm_storage_account" "this" {
  count                           = var.enable_service_endpoints ? 1 : 0
  account_replication_type        = "ZRS"
  account_tier                    = "Standard"
  location                        = azurerm_resource_group.this.location
  name                            = "sa${replace(var.name, "-", "")}"
  resource_group_name             = azurerm_resource_group.this.name
  allow_nested_items_to_be_public = false
  shared_access_key_enabled       = false
  https_traffic_only_enabled      = true
  min_tls_version                 = "TLS1_2"
  tags                            = var.tags
}

resource "azurerm_subnet_service_endpoint_storage_policy" "this" {
  count               = var.enable_service_endpoints ? 1 : 0
  location            = azurerm_resource_group.this.location
  name                = "sep-${var.name}"
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags

  definition {
    name = "${var.name}-policy"
    service_resources = [
      azurerm_resource_group.this.id,
      azurerm_storage_account.this[0].id
    ]
    description = "Service endpoint policy for storage account"
    service     = "Microsoft.Storage"
  }
}

resource "azurerm_user_assigned_identity" "this" {
  count               = var.enable_managed_identity ? 1 : 0
  location            = azurerm_resource_group.this.location
  name                = "id-${var.name}"
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}

resource "azurerm_log_analytics_workspace" "this" {
  count               = var.enable_log_analytics_workspace ? 1 : 0
  location            = azurerm_resource_group.this.location
  name                = "log-${var.name}"
  resource_group_name = azurerm_resource_group.this.name
  tags                = var.tags
}