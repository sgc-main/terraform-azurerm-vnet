output name {
  description = "The name of the forward peering resource"
  value       = azapi_resource.peering["forward"].name
}

output resource_id {
  description = "The resource ID of the forward peering resource"
  value       = azapi_resource.peering["forward"].id
}

output reverse_name {
  description = "The name of the reverse peering resource (null if no reverse)"
  value       = try(azapi_resource.peering["reverse"].name, null)
}

output reverse_resource_id {
  description = "The resource ID of the reverse peering resource (null if no reverse)"
  value       = try(azapi_resource.peering["reverse"].id, null)
}
