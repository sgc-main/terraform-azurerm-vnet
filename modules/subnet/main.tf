locals {
  ipam_enabled = var.ipam_pools != null
}

resource "azapi_resource" "subnet" {
  name      = var.name
  parent_id = var.parent_id
  type      = "Microsoft.Network/virtualNetworks/subnets@2024-07-01"

  body = {
    properties = merge(
      # Address: IPAM pool allocation or static prefixes (mutually exclusive)
      local.ipam_enabled ? {
        ipamPoolPrefixAllocations = [
          for pool in var.ipam_pools : {
            pool                = { id = pool.pool_id }
            numberOfIpAddresses = tostring(pow(2, 32 - pool.prefix_length))
          }
        ]
      } : {
        addressPrefixes = var.address_prefixes
      },
      # Common subnet properties
      {
        defaultOutboundAccess = var.default_outbound_access_enabled
        delegations = var.delegations != null ? [
          for d in var.delegations : {
            name       = d.name
            properties = { serviceName = d.service_delegation.name }
          }
        ] : []
        natGateway                        = var.nat_gateway
        networkSecurityGroup              = var.network_security_group
        privateEndpointNetworkPolicies    = var.private_endpoint_network_policies
        privateLinkServiceNetworkPolicies = var.private_link_service_network_policies_enabled == false ? "Disabled" : "Enabled"
        routeTable                        = var.route_table
        serviceEndpoints = var.service_endpoints_with_location != null ? [
          for ep in var.service_endpoints_with_location : {
            service   = ep.service
            locations = ep.locations
          }
        ] : null
        serviceEndpointPolicies = var.service_endpoint_policies != null ? [
          for sep in var.service_endpoint_policies : { id = sep.id }
        ] : null
      }
    )
  }

  locks                     = [var.parent_id]
  response_export_values    = ["properties.addressPrefixes", "properties.addressPrefix"]
  schema_validation_enabled = true

  retry = var.retry

  timeouts {
    create = var.timeouts.create
    read   = var.timeouts.read
    update = var.timeouts.update
    delete = var.timeouts.delete
  }
}

resource "azurerm_role_assignment" "this" {
  for_each = var.role_assignments

  principal_id                           = each.value.principal_id
  scope                                  = azapi_resource.subnet.id
  condition                              = each.value.condition
  condition_version                      = each.value.condition_version
  delegated_managed_identity_resource_id = each.value.delegated_managed_identity_resource_id
  principal_type                         = each.value.principal_type
  role_definition_id                     = strcontains(lower(each.value.role_definition_id_or_name), lower("/providers/Microsoft.Authorization/roleDefinitions/")) ? each.value.role_definition_id_or_name : null
  role_definition_name                   = strcontains(lower(each.value.role_definition_id_or_name), lower("/providers/Microsoft.Authorization/roleDefinitions/")) ? null : each.value.role_definition_id_or_name
  skip_service_principal_aad_check       = each.value.skip_service_principal_aad_check
}
