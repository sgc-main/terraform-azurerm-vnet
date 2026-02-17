locals {
  role_definition_resource_substring = "/providers/Microsoft.Authorization/roleDefinitions"
}

resource "azapi_resource" "vnet" {
  name      = var.name
  parent_id = var.parent_id
  location  = var.location
  type      = "Microsoft.Network/virtualNetworks@2024-07-01"

  body = {
    properties = {
      addressSpace = merge(
        var.ipam_pools != null ? {
          ipamPoolPrefixAllocations = [
            for pool in var.ipam_pools : {
              numberOfIpAddresses = tostring(pow(2, (pool.prefix_length >= 48 ? 128 : 32) - pool.prefix_length))
              pool                = { id = pool.id }
            }
          ]
        } : {},
        var.ipam_pools == null ? {
          addressPrefixes = var.address_space != null ? var.address_space : []
        } : {}
      )
      bgpCommunities = var.bgp_community != null ? {
        virtualNetworkCommunity = var.bgp_community
      } : null
      dhcpOptions = var.dns_servers != null ? {
        dnsServers = var.dns_servers.dns_servers
      } : null
      ddosProtectionPlan = var.ddos_protection_plan != null ? {
        id = var.ddos_protection_plan.id
      } : null
      enableDdosProtection = var.ddos_protection_plan != null ? var.ddos_protection_plan.enable : false
      enableVmProtection   = var.enable_vm_protection
      encryption = var.encryption != null ? {
        enabled     = var.encryption.enabled
        enforcement = var.encryption.enforcement
      } : null
      flowTimeoutInMinutes = var.flow_timeout_in_minutes
    }
    extendedLocation = var.extended_location != null ? {
      name = var.extended_location.name
      type = var.extended_location.type
    } : null
  }

  response_export_values = var.ipam_pools != null ? [
    "properties.addressSpace.addressPrefixes"
  ] : []
  retry                  = var.retry
  tags                   = var.tags
  schema_validation_enabled = true

  timeouts {
    create = var.timeouts.create
    delete = var.timeouts.delete
    read   = var.timeouts.read
    update = var.timeouts.update
  }
}
