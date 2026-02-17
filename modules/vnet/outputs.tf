output address_spaces {
  description = "The address spaces of the virtual network"
  value       = var.ipam_pools != null ? azapi_resource.vnet.output.properties.addressSpace.addressPrefixes : var.address_space
}

output name {
  description = "The virtual network name"
  value       = azapi_resource.vnet.name
}

output resource {
  description = "The full azapi VNet resource object"
  value       = azapi_resource.vnet
}

output resource_id {
  description = "The virtual network resource ID"
  value       = azapi_resource.vnet.id
}
