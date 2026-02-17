module "peering" {
  source   = "./modules/peering"
  for_each = var.peerings

  name                      = each.key
  parent_id                 = module.vnet.resource_id
  remote_virtual_network_id = each.value.remote_virtual_network_resource_id

  # Forward settings
  allow_forwarded_traffic      = each.value.allow_forwarded_traffic
  allow_gateway_transit        = each.value.allow_gateway_transit
  allow_virtual_network_access = each.value.allow_virtual_network_access
  do_not_verify_remote_gateways = each.value.do_not_verify_remote_gateways
  enable_only_ipv6_peering     = each.value.enable_only_ipv6_peering
  peer_complete_vnets          = each.value.peer_complete_vnets
  use_remote_gateways          = each.value.use_remote_gateways
  local_peered_address_spaces  = each.value.local_peered_address_spaces
  remote_peered_address_spaces = each.value.remote_peered_address_spaces
  local_peered_subnets         = each.value.local_peered_subnets
  remote_peered_subnets        = each.value.remote_peered_subnets

  # Reverse settings — null values mirror forward in the submodule
  create_reverse_peering                = each.value.create_reverse_peering
  reverse_name                          = each.value.reverse_name
  reverse_allow_forwarded_traffic       = each.value.reverse_allow_forwarded_traffic
  reverse_allow_gateway_transit         = each.value.reverse_allow_gateway_transit
  reverse_allow_virtual_network_access  = each.value.reverse_allow_virtual_network_access
  reverse_do_not_verify_remote_gateways = each.value.reverse_do_not_verify_remote_gateways
  reverse_enable_only_ipv6_peering      = each.value.reverse_enable_only_ipv6_peering
  reverse_peer_complete_vnets           = each.value.reverse_peer_complete_vnets
  reverse_use_remote_gateways           = each.value.reverse_use_remote_gateways
  reverse_local_peered_address_spaces   = each.value.reverse_local_peered_address_spaces
  reverse_remote_peered_address_spaces  = each.value.reverse_remote_peered_address_spaces
  reverse_local_peered_subnets          = each.value.reverse_local_peered_subnets
  reverse_remote_peered_subnets         = each.value.reverse_remote_peered_subnets

  # Sync / operational
  sync_remote_address_space_enabled  = each.value.sync_remote_address_space_enabled
  sync_remote_address_space_triggers = each.value.sync_remote_address_space_triggers
  timeouts                           = each.value.timeouts
  retry                              = each.value.retry

  depends_on = [module.subnet]
}
