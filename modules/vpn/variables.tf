# ─── Gateway Settings ────────────────────────────────────────────────────────

variable name {
  description = "Base name for VPN resources (pip-vpngw-{name}, vpngw-{name})"
  type        = string
  nullable    = false
}

variable resource_group_name {
  description = "Resource group for all VPN resources"
  type        = string
  nullable    = false
}

variable location {
  description = "Azure region for VPN resources"
  type        = string
  nullable    = false
}

variable gateway_subnet_id {
  description = "GatewaySubnet resource ID — must exist before the VPN gateway can be created"
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("GatewaySubnet$", var.gateway_subnet_id))
    error_message = "Must be a GatewaySubnet resource ID (ending in /subnets/GatewaySubnet)."
  }
}

variable sku {
  description = "VPN Gateway SKU: VpnGw1, VpnGw1AZ, VpnGw2, VpnGw2AZ, VpnGw3, VpnGw3AZ, VpnGw4, VpnGw4AZ, VpnGw5, VpnGw5AZ"
  type        = string
  default     = "VpnGw2"
  nullable    = false

  validation {
    condition     = can(regex("^VpnGw[1-5](AZ)?$", var.sku))
    error_message = "Must be a valid VPN Gateway SKU (VpnGw1–VpnGw5, optionally with AZ suffix)."
  }
}

variable generation {
  description = "VPN Gateway generation: Generation1 or Generation2"
  type        = string
  default     = "Generation2"
  nullable    = false

  validation {
    condition     = contains(["Generation1", "Generation2"], var.generation)
    error_message = "Must be Generation1 or Generation2."
  }
}

variable vpn_type {
  description = "VPN type: RouteBased (recommended) or PolicyBased"
  type        = string
  default     = "RouteBased"
  nullable    = false

  validation {
    condition     = contains(["RouteBased", "PolicyBased"], var.vpn_type)
    error_message = "Must be RouteBased or PolicyBased."
  }
}

variable active_active {
  description = "Enable active-active mode (requires 2 public IPs)"
  type        = bool
  default     = false
  nullable    = false
}

variable enable_bgp {
  description = "Enable BGP on the VPN gateway"
  type        = bool
  default     = true
  nullable    = false
}

variable bgp_asn {
  description = "BGP Autonomous System Number for the VPN gateway"
  type        = number
  default     = 65515
  nullable    = false
}

variable tags {
  description = "Tags applied to all VPN resources"
  type        = map(string)
  default     = {}
}

# ─── VPN Connections ─────────────────────────────────────────────────────────

variable vpn_connections {
  description = <<-EOT
    Map of VPN connection configurations. Key is used as a name suffix.
    Each connection creates a Local Network Gateway and a VPN Connection.

    Modeled after the AWS vpn_connections variable pattern:
    - peer_ip_address         — remote gateway public IP
    - shared_key              — IPsec pre-shared key
    - address_space           — remote network CIDRs (static routing)
    - enable_bgp              — use BGP for this connection (overrides static)
    - bgp_asn / bgp_peering_address — remote BGP peer settings
    - ipsec_policy            — custom IPsec/IKE parameters (null = Azure defaults)
    - connection_protocol     — IKEv1 or IKEv2
    - dpd_timeout_seconds     — dead peer detection timeout
    - use_policy_based_traffic_selectors — required for some on-prem devices
    - routing_weight          — route priority (lower = preferred)
    - tags                    — per-connection tags (merged with module tags)
  EOT
  type = map(object({
    # Required
    peer_ip_address = string
    shared_key      = string

    # Remote network (required for static routing, ignored with BGP)
    address_space = optional(list(string), [])

    # BGP settings for this connection's remote peer
    enable_bgp          = optional(bool, false)
    bgp_asn             = optional(number, null)
    bgp_peering_address = optional(string, null)

    # IPsec/IKE policy — null uses Azure defaults
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

    # Connection settings
    connection_protocol                = optional(string, "IKEv2")
    dpd_timeout_seconds                = optional(number, 45)
    use_policy_based_traffic_selectors = optional(bool, false)
    routing_weight                     = optional(number, 0)

    # Per-connection tags (merged with module-level tags)
    tags = optional(map(string), {})
  }))
  default  = {}
  nullable = false
}
