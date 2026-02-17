variable name {
  description = "Resource name base (used as prefix for all child resources)"
  type        = string
}

variable location {
  description = "Azure region for deployment"
  type        = string
}

variable tags {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

variable vnet_address_space {
  description = "VNet address space CIDRs. Mutually exclusive with ipam_pools."
  type        = set(string)
  default     = null
}

variable ipam_pools {
  description = "IPAM pool allocation. Mutually exclusive with vnet_address_space."
  type = list(object({
    id            = string
    prefix_length = number
  }))
  default = null
}

variable subnets {
  description = "Map of subnets - key patterns: 'pub/appgw/gateway' for public, 'aks/node/k8s/pod' for AKS"
  type        = map(list(string))
  default     = {}
}

variable enable_nat_gateway {
  description = "Enable NAT Gateway for private subnets"
  type        = bool
  default     = true
}

variable enable_nsg {
  description = "Enable Network Security Group"
  type        = bool
  default     = true
}

variable enable_route_table {
  description = "Enable Route Table"
  type        = bool
  default     = true
}

variable enable_service_endpoints {
  description = "Enable Service Endpoints and Storage Account"
  type        = bool
  default     = true
}

variable enable_log_analytics_workspace {
  description = "Create a Log Analytics Workspace in the VNet resource group"
  type        = bool
  default     = false
}

variable enable_managed_identity {
  description = "Create a User Assigned Managed Identity in the VNet resource group"
  type        = bool
  default     = false
}

variable extra_service_endpoints {
  description = "Additional service endpoints to add to all private non-AKS subnets (merged with baseline: Storage, KeyVault)"
  type        = list(string)
  default     = []
}

variable extra_aks_service_endpoints {
  description = "Additional service endpoints to add to AKS subnets (merged with baseline: ContainerRegistry, Storage, KeyVault, Sql)"
  type        = list(string)
  default     = []
}

variable enable_web_delegation {
  description = "Enable Web/serverFarms delegation for subnets with 'func' or 'web' in the key"
  type        = bool
  default     = true
}

variable enable_app_gateway_delegation {
  description = "Enable Application Gateway delegation for subnets with 'appgw' or 'gateway' in the key"
  type        = bool
  default     = true
}

variable use_azure_firewall {
  description = "Route private subnet traffic through Azure Firewall instead of NAT Gateway"
  type        = bool
  default     = false
}

variable azure_firewall_private_ip {
  description = "Azure Firewall private IP address (required if use_azure_firewall = true)"
  type        = string
  default     = ""
}

variable nsg_rules {
  description = "Map of NSG security rules. Key is the rule name. Empty by default (no rules)."
  type = map(object({
    priority                     = number
    direction                    = string # "Inbound" or "Outbound"
    access                       = string # "Allow" or "Deny"
    protocol                     = string # "Tcp", "Udp", "Icmp", "Esp", "Ah", or "*"
    source_port_range            = optional(string, "*")
    destination_port_range       = optional(string)
    source_port_ranges           = optional(list(string))
    destination_port_ranges      = optional(list(string))
    source_address_prefix        = optional(string)
    destination_address_prefix   = optional(string)
    source_address_prefixes      = optional(list(string))
    destination_address_prefixes = optional(list(string))
    description                  = optional(string)
  }))
  default = {}
}

variable private_endpoint_network_policies {
  description = <<-EOT
    Controls NSG/UDR enforcement on private endpoint traffic for private subnets.
    Public subnets always get "Disabled". Possible values:
    - "Enabled"                    — NSG + UDR apply to PE traffic (recommended default)
    - "Disabled"                   — PE traffic bypasses all network controls
    - "NetworkSecurityGroupEnabled" — only NSG applies (UDR bypassed)
    - "RouteTableEnabled"          — only UDR applies (NSG bypassed)
  EOT
  type        = string
  default     = "Enabled"
  nullable    = false

  validation {
    condition     = can(regex("^(Disabled|Enabled|NetworkSecurityGroupEnabled|RouteTableEnabled)$", var.private_endpoint_network_policies))
    error_message = "Must be one of: Disabled, Enabled, NetworkSecurityGroupEnabled, RouteTableEnabled."
  }
}

variable private_link_subnets {
  description = <<-EOT
    List of subnet keys (from var.subnets) that host Azure Private Link Services.
    Only these subnets will have private_link_service_network_policies_enabled = false.
    This is required ONLY when deploying a Private Link Service (not a regular ILB).
    Disabling network policies removes NSG/UDR enforcement on PLS traffic in the subnet.
  EOT
  type        = list(string)
  default     = []
}

variable subnet_delegations {
  description = <<-EOT
    Explicit subnet delegations. Key is the subnet key from var.subnets.
    Overrides auto-detected delegations (appgw, web/func patterns).
    Example:
      subnet_delegations = {
        priv-services = [{
          name = "Microsoft.Sql.managedInstances"
          service_delegation = {
            name = "Microsoft.Sql/managedInstances"
          }
        }]
      }
  EOT
  type = map(list(object({
    name = string
    service_delegation = object({
      name = string
    })
  })))
  default = {}
}

variable subnet_ipam_pools {
  description = <<-EOT
    Per-subnet IPAM pool allocations. Key is the subnet key from var.subnets.
    When set for a subnet, address_prefixes from var.subnets is ignored.
    Requires the parent VNet to be IPAM-enabled (var.ipam_pools).
    Example:
      subnet_ipam_pools = {
        priv-app = [{ pool_id = "/subscriptions/.../ipamPools/mypool", prefix_length = 24 }]
      }
  EOT
  type = map(list(object({
    pool_id       = string
    prefix_length = number
  })))
  default = {}
}

variable peerings {
  type = map(object({
    remote_virtual_network_resource_id = string
    allow_forwarded_traffic            = optional(bool, false)
    allow_gateway_transit              = optional(bool, false)
    allow_virtual_network_access       = optional(bool, true)
    do_not_verify_remote_gateways      = optional(bool, false)
    enable_only_ipv6_peering           = optional(bool, false)
    peer_complete_vnets                = optional(bool, true)
    use_remote_gateways                = optional(bool, false)
    local_peered_address_spaces = optional(list(object({
      address_prefix = string
    })))
    remote_peered_address_spaces = optional(list(object({
      address_prefix = string
    })))
    local_peered_subnets = optional(list(object({
      subnet_name = string
    })))
    remote_peered_subnets = optional(list(object({
      subnet_name = string
    })))
    # Reverse peering — null values mirror forward settings
    create_reverse_peering                = optional(bool, false)
    reverse_name                          = optional(string)
    reverse_allow_forwarded_traffic       = optional(bool)
    reverse_allow_gateway_transit         = optional(bool)
    reverse_allow_virtual_network_access  = optional(bool)
    reverse_do_not_verify_remote_gateways = optional(bool)
    reverse_enable_only_ipv6_peering      = optional(bool)
    reverse_peer_complete_vnets           = optional(bool)
    reverse_use_remote_gateways           = optional(bool)
    reverse_local_peered_address_spaces = optional(list(object({
      address_prefix = string
    })))
    reverse_remote_peered_address_spaces = optional(list(object({
      address_prefix = string
    })))
    reverse_local_peered_subnets = optional(list(object({
      subnet_name = string
    })))
    reverse_remote_peered_subnets = optional(list(object({
      subnet_name = string
    })))
    # Operational
    sync_remote_address_space_enabled  = optional(bool, false)
    sync_remote_address_space_triggers = optional(any, null)
    timeouts = optional(object({
      create = optional(string, "30m")
      read   = optional(string, "5m")
      update = optional(string, "30m")
      delete = optional(string, "30m")
    }), {})
    retry = optional(object({
      error_message_regex  = optional(list(string), ["ReferencedResourceNotProvisioned"])
      interval_seconds     = optional(number, 10)
      max_interval_seconds = optional(number, 180)
    }), {})
  }))
  default     = {}
  description = <<-EOT
    Map of VNet peering configurations. Key is a unique identifier.

    Forward peering settings control the peering from local→remote.
    Reverse peering settings default to null and **mirror forward settings** —
    only specify reverse_* properties when the reverse needs different values.

    When create_reverse_peering = true and no reverse_* overrides are given,
    the reverse peering is created with identical settings to the forward.
    Address-space and subnet scopes swap local↔remote automatically.

    Peering modes (controlled by peer_complete_vnets):
    - true  — peers the entire VNet (default)
    - false — requires either peered_address_spaces or peered_subnets
  EOT
  nullable    = false
}

# ─── VPN Gateway ─────────────────────────────────────────────────────────────

variable enable_vpn_gateway {
  description = <<-EOT
    Enable VPN Gateway deployment. Requires a "GatewaySubnet" key in var.subnets.
    Creates a Virtual Network Gateway, public IP(s), and any configured VPN connections.
  EOT
  type        = bool
  default     = false
  nullable    = false
}

variable vpn_gateway_sku {
  description = "VPN Gateway SKU: VpnGw1–VpnGw5, optionally with AZ suffix for zone-redundancy"
  type        = string
  default     = "VpnGw2"
  nullable    = false
}

variable vpn_gateway_generation {
  description = "VPN Gateway generation: Generation1 or Generation2"
  type        = string
  default     = "Generation2"
  nullable    = false
}

variable vpn_gateway_type {
  description = "VPN type: RouteBased (recommended) or PolicyBased"
  type        = string
  default     = "RouteBased"
  nullable    = false
}

variable vpn_gateway_active_active {
  description = "Enable active-active VPN gateway (creates 2 public IPs and 2 tunnels)"
  type        = bool
  default     = false
  nullable    = false
}

variable vpn_gateway_enable_bgp {
  description = "Enable BGP on the VPN gateway"
  type        = bool
  default     = true
  nullable    = false
}

variable vpn_gateway_bgp_asn {
  description = "BGP ASN for the VPN gateway (Azure default is 65515)"
  type        = number
  default     = 65515
  nullable    = false
}

variable vpn_connections {
  description = <<-EOT
    Map of VPN connection configurations. Key is used as a name suffix.
    Each entry creates a Local Network Gateway + VPN Connection.

    Modeled after the AWS vpn_connections variable pattern:
    - peer_ip_address    — remote gateway public IP (Required)
    - shared_key         — IPsec pre-shared key (Required)
    - address_space      — remote CIDRs for static routing
    - enable_bgp         — use BGP instead of static routes
    - bgp_asn            — remote peer BGP ASN
    - bgp_peering_address — remote peer BGP IP
    - ipsec_policy        — custom IPsec/IKE parameters (null = Azure defaults)
    - connection_protocol — IKEv1 or IKEv2
    - dpd_timeout_seconds — dead peer detection timeout
    - use_policy_based_traffic_selectors — for policy-based on-prem devices
    - routing_weight      — route priority (lower = preferred)
    - tags                — per-connection tags (merged with module tags)
  EOT
  type = map(object({
    peer_ip_address = string
    shared_key      = string
    address_space   = optional(list(string), [])

    enable_bgp          = optional(bool, false)
    bgp_asn             = optional(number, null)
    bgp_peering_address = optional(string, null)

    ipsec_policy = optional(object({
      ike_encryption   = optional(string, "AES256")
      ike_integrity    = optional(string, "SHA256")
      dh_group         = optional(string, "DHGroup14")
      ipsec_encryption = optional(string, "AES256")
      ipsec_integrity  = optional(string, "SHA256")
      pfs_group        = optional(string, "PFS14")
      sa_lifetime      = optional(number, 3600)
      sa_datasize      = optional(number, null)
    }), null)

    connection_protocol                = optional(string, "IKEv2")
    dpd_timeout_seconds                = optional(number, 45)
    use_policy_based_traffic_selectors = optional(bool, false)
    routing_weight                     = optional(number, 0)

    tags = optional(map(string), {})
  }))
  default  = {}
  nullable = false
}
