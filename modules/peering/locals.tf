locals {
  # ─── Resolved reverse settings (mirror forward when null) ──────────────────
  reverse_allow_forwarded_traffic       = coalesce(var.reverse_allow_forwarded_traffic, var.allow_forwarded_traffic)
  reverse_allow_gateway_transit         = coalesce(var.reverse_allow_gateway_transit, var.allow_gateway_transit)
  reverse_allow_virtual_network_access  = coalesce(var.reverse_allow_virtual_network_access, var.allow_virtual_network_access)
  reverse_do_not_verify_remote_gateways = coalesce(var.reverse_do_not_verify_remote_gateways, var.do_not_verify_remote_gateways)
  reverse_enable_only_ipv6_peering      = coalesce(var.reverse_enable_only_ipv6_peering, var.enable_only_ipv6_peering)
  reverse_peer_complete_vnets           = coalesce(var.reverse_peer_complete_vnets, var.peer_complete_vnets)
  reverse_use_remote_gateways           = coalesce(var.reverse_use_remote_gateways, var.use_remote_gateways)

  # Address spaces / subnets — reverse swaps local↔remote
  reverse_local_peered_address_spaces  = coalesce(var.reverse_local_peered_address_spaces, var.remote_peered_address_spaces, [])
  reverse_remote_peered_address_spaces = coalesce(var.reverse_remote_peered_address_spaces, var.local_peered_address_spaces, [])
  reverse_local_peered_subnets         = coalesce(var.reverse_local_peered_subnets, var.remote_peered_subnets, [])
  reverse_remote_peered_subnets        = coalesce(var.reverse_remote_peered_subnets, var.local_peered_subnets, [])

  # ─── Peering config map — forward always present, reverse conditional ──────
  peerings = merge(
    {
      forward = {
        name                         = var.name
        parent_id                    = var.parent_id
        remote_virtual_network_id    = var.remote_virtual_network_id
        allow_forwarded_traffic      = var.allow_forwarded_traffic
        allow_gateway_transit        = var.allow_gateway_transit
        allow_virtual_network_access = var.allow_virtual_network_access
        do_not_verify_remote_gateways = var.do_not_verify_remote_gateways
        enable_only_ipv6_peering     = var.enable_only_ipv6_peering
        peer_complete_vnets          = var.peer_complete_vnets
        use_remote_gateways          = var.use_remote_gateways
        local_peered_address_spaces  = coalesce(var.local_peered_address_spaces, [])
        remote_peered_address_spaces = coalesce(var.remote_peered_address_spaces, [])
        local_peered_subnets         = coalesce(var.local_peered_subnets, [])
        remote_peered_subnets        = coalesce(var.remote_peered_subnets, [])
      }
    },
    var.create_reverse_peering ? {
      reverse = {
        name                         = var.reverse_name
        parent_id                    = var.remote_virtual_network_id
        remote_virtual_network_id    = var.parent_id
        allow_forwarded_traffic      = local.reverse_allow_forwarded_traffic
        allow_gateway_transit        = local.reverse_allow_gateway_transit
        allow_virtual_network_access = local.reverse_allow_virtual_network_access
        do_not_verify_remote_gateways = local.reverse_do_not_verify_remote_gateways
        enable_only_ipv6_peering     = local.reverse_enable_only_ipv6_peering
        peer_complete_vnets          = local.reverse_peer_complete_vnets
        use_remote_gateways          = local.reverse_use_remote_gateways
        local_peered_address_spaces  = local.reverse_local_peered_address_spaces
        remote_peered_address_spaces = local.reverse_remote_peered_address_spaces
        local_peered_subnets         = local.reverse_local_peered_subnets
        remote_peered_subnets        = local.reverse_remote_peered_subnets
      }
    } : {}
  )

  # ─── Sync subset — only peering keys that need sync update resources ───────
  sync_peerings = var.sync_remote_address_space_enabled ? local.peerings : {}

  sync_remote_address_space_query_parameter = {
    syncRemoteAddressSpace = ["true"]
  }
}
