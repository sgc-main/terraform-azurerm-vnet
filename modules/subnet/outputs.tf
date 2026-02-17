output address_prefixes {
  description = "The address prefixes of the subnet (dynamically allocated for IPAM subnets)"
  value = try(
    azapi_resource.subnet.output.properties.addressPrefixes,
    [azapi_resource.subnet.output.properties.addressPrefix],
    []
  )
}

output name {
  description = "The subnet name"
  value       = azapi_resource.subnet.name
}

output resource_id {
  description = "The subnet resource ID"
  value       = azapi_resource.subnet.id
}
