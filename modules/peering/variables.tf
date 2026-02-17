variable name {
  description = "The name of the virtual network peering"
  type        = string
  nullable    = false
}

variable parent_id {
  description = "The local Virtual Network resource ID (peering is created here)"
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+$", var.parent_id))
    error_message = "Must be a valid Virtual Network resource ID."
  }
}

variable remote_virtual_network_id {
  description = "The remote Virtual Network resource ID to peer with"
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+$", var.remote_virtual_network_id))
    error_message = "Must be a valid Virtual Network resource ID."
  }
}

# ─── Forward peering settings ────────────────────────────────────────────────

variable allow_forwarded_traffic {
  description = "Allow forwarded traffic between the virtual networks"
  type        = bool
  default     = false
  nullable    = false
}

variable allow_gateway_transit {
  description = "Allow gateway transit between the virtual networks"
  type        = bool
  default     = false
  nullable    = false
}

variable allow_virtual_network_access {
  description = "Allow access from the local VNet to the remote VNet"
  type        = bool
  default     = true
  nullable    = false
}

variable do_not_verify_remote_gateways {
  description = "Skip remote gateway verification"
  type        = bool
  default     = false
  nullable    = false
}

variable enable_only_ipv6_peering {
  description = "Enable only IPv6 peering"
  type        = bool
  default     = false
  nullable    = false
}

variable peer_complete_vnets {
  description = "Peer complete virtual networks. Set to false for address-space or subnet-scoped peering."
  type        = bool
  default     = true
  nullable    = false

  validation {
    condition = var.peer_complete_vnets || (!var.peer_complete_vnets && (
      (length(coalesce(var.local_peered_address_spaces, [])) > 0 && length(coalesce(var.remote_peered_address_spaces, [])) > 0) ||
      (length(coalesce(var.local_peered_subnets, [])) > 0 && length(coalesce(var.remote_peered_subnets, [])) > 0)
    ))
    error_message = "When peer_complete_vnets is false, provide either peered_address_spaces or peered_subnets (both local and remote)."
  }
}

variable use_remote_gateways {
  description = "Use remote gateways for the virtual network peering"
  type        = bool
  default     = false
  nullable    = false
}

variable local_peered_address_spaces {
  description = "Local address prefixes to peer (only when peer_complete_vnets = false)"
  type = list(object({
    address_prefix = string
  }))
  default = []
}

variable remote_peered_address_spaces {
  description = "Remote address prefixes to peer (only when peer_complete_vnets = false)"
  type = list(object({
    address_prefix = string
  }))
  default = []
}

variable local_peered_subnets {
  description = "Local subnet names to peer (only when peer_complete_vnets = false)"
  type = list(object({
    subnet_name = string
  }))
  default = []
}

variable remote_peered_subnets {
  description = "Remote subnet names to peer (only when peer_complete_vnets = false)"
  type = list(object({
    subnet_name = string
  }))
  default = []
}

# ─── Reverse peering settings (mirror forward by default) ────────────────────

variable create_reverse_peering {
  description = "Create a reverse peering from the remote VNet to the local VNet"
  type        = bool
  default     = false
  nullable    = false
}

variable reverse_name {
  description = "Name of the reverse peering. Required when create_reverse_peering = true."
  type        = string
  default     = null
}

variable reverse_allow_forwarded_traffic {
  description = "Allow forwarded traffic for reverse peering (null = mirrors forward)"
  type        = bool
  default     = null
}

variable reverse_allow_gateway_transit {
  description = "Allow gateway transit for reverse peering (null = mirrors forward)"
  type        = bool
  default     = null
}

variable reverse_allow_virtual_network_access {
  description = "Allow VNet access for reverse peering (null = mirrors forward)"
  type        = bool
  default     = null
}

variable reverse_do_not_verify_remote_gateways {
  description = "Skip remote gateway verification for reverse peering (null = mirrors forward)"
  type        = bool
  default     = null
}

variable reverse_enable_only_ipv6_peering {
  description = "Enable only IPv6 for reverse peering (null = mirrors forward)"
  type        = bool
  default     = null
}

variable reverse_peer_complete_vnets {
  description = "Peer complete VNets for reverse peering (null = mirrors forward)"
  type        = bool
  default     = null
}

variable reverse_use_remote_gateways {
  description = "Use remote gateways for reverse peering (null = mirrors forward)"
  type        = bool
  default     = null
}

variable reverse_local_peered_address_spaces {
  description = "Local address prefixes for reverse peering (null = mirrors remote_peered_address_spaces)"
  type = list(object({
    address_prefix = string
  }))
  default = null
}

variable reverse_remote_peered_address_spaces {
  description = "Remote address prefixes for reverse peering (null = mirrors local_peered_address_spaces)"
  type = list(object({
    address_prefix = string
  }))
  default = null
}

variable reverse_local_peered_subnets {
  description = "Local subnets for reverse peering (null = mirrors remote_peered_subnets)"
  type = list(object({
    subnet_name = string
  }))
  default = null
}

variable reverse_remote_peered_subnets {
  description = "Remote subnets for reverse peering (null = mirrors local_peered_subnets)"
  type = list(object({
    subnet_name = string
  }))
  default = null
}

# ─── Sync / retry / timeouts ────────────────────────────────────────────────

variable sync_remote_address_space_enabled {
  description = "Sync the remote address space when it changes"
  type        = bool
  default     = false
  nullable    = false
}

variable sync_remote_address_space_triggers {
  description = "A value that when changed triggers a resync. Required when sync is enabled."
  type        = any
  default     = null

  validation {
    condition     = !var.sync_remote_address_space_enabled || (var.sync_remote_address_space_enabled && var.sync_remote_address_space_triggers != null)
    error_message = "sync_remote_address_space_triggers must be set when sync_remote_address_space_enabled is true."
  }
}

variable retry {
  description = "Retry configuration for resource operations"
  type = object({
    error_message_regex  = optional(list(string), ["ReferencedResourceNotProvisioned"])
    interval_seconds     = optional(number, 10)
    max_interval_seconds = optional(number, 180)
  })
  default = {}
}

variable timeouts {
  description = "Timeouts for resource operations"
  type = object({
    create = optional(string, "30m")
    read   = optional(string, "5m")
    update = optional(string, "30m")
    delete = optional(string, "30m")
  })
  default = {}
}
