# ═══════════════════════════════════════════════════════════════════════════════
# VNet Peering — single resource handles all 3 modes (full / address-space / subnet)
# for both forward and reverse directions via for_each over local.peerings.
#
# The body is constructed with merge() — address-space and subnet scope
# properties are conditionally included only when the peering is scoped.
# ═══════════════════════════════════════════════════════════════════════════════

resource "azapi_resource" "peering" {
  for_each = local.peerings

  name      = each.value.name
  parent_id = each.value.parent_id
  type      = "Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-07-01"

  body = {
    properties = merge(
      {
        remoteVirtualNetwork      = { id = each.value.remote_virtual_network_id }
        allowVirtualNetworkAccess = each.value.allow_virtual_network_access
        allowForwardedTraffic     = each.value.allow_forwarded_traffic
        allowGatewayTransit       = each.value.allow_gateway_transit
        useRemoteGateways         = each.value.use_remote_gateways
        doNotVerifyRemoteGateways = each.value.do_not_verify_remote_gateways
        enableOnlyIPv6Peering     = each.value.enable_only_ipv6_peering
        peerCompleteVnets         = each.value.peer_complete_vnets
      },
      # Address-space scoped — include only when prefixes are provided
      length(each.value.local_peered_address_spaces) > 0 ? {
        localAddressSpace = {
          addressPrefixes = [for a in each.value.local_peered_address_spaces : a.address_prefix]
        }
      } : {},
      length(each.value.remote_peered_address_spaces) > 0 ? {
        remoteAddressSpace = {
          addressPrefixes = [for a in each.value.remote_peered_address_spaces : a.address_prefix]
        }
      } : {},
      # Subnet scoped — include only when subnet names are provided
      length(each.value.local_peered_subnets) > 0 ? {
        localSubnetNames = [for s in each.value.local_peered_subnets : s.subnet_name]
      } : {},
      length(each.value.remote_peered_subnets) > 0 ? {
        remoteSubnetNames = [for s in each.value.remote_peered_subnets : s.subnet_name]
      } : {},
    )
  }

  locks                     = [each.value.parent_id]
  response_export_values    = []
  retry                     = var.retry
  schema_validation_enabled = true

  timeouts {
    create = var.timeouts.create
    delete = var.timeouts.delete
    read   = var.timeouts.read
    update = var.timeouts.update
  }
}

# ═══════════════════════════════════════════════════════════════════════════════
# Remote address space sync — triggers re-sync when remote VNet address space
# changes. Uses azapi_update_resource with syncRemoteAddressSpace query param.
# Only created when sync_remote_address_space_enabled = true.
# ═══════════════════════════════════════════════════════════════════════════════

resource "terraform_data" "sync_remote_address_space_triggers" {
  count            = var.sync_remote_address_space_enabled ? 1 : 0
  triggers_replace = var.sync_remote_address_space_triggers
}

resource "azapi_update_resource" "sync" {
  for_each = local.sync_peerings

  resource_id             = azapi_resource.peering[each.key].id
  type                    = "Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-07-01"
  update_query_parameters = local.sync_remote_address_space_query_parameter

  lifecycle {
    replace_triggered_by = [terraform_data.sync_remote_address_space_triggers]
  }
}
