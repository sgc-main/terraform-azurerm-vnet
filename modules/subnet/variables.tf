variable name {
  description = "Subnet name"
  type        = string
}

variable parent_id {
  description = "Virtual Network resource ID"
  type        = string

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+$", var.parent_id))
    error_message = "Must be a valid Virtual Network resource ID."
  }
}

variable address_prefixes {
  description = "Static address prefixes. Mutually exclusive with ipam_pools."
  type        = list(string)
  default     = null
}

variable ipam_pools {
  description = "IPAM pool allocations. Mutually exclusive with address_prefixes."
  type = list(object({
    pool_id       = string
    prefix_length = number
  }))
  default = null

  validation {
    condition     = var.ipam_pools == null ? true : length(var.ipam_pools) == 1
    error_message = "Only one IPAM pool allocation per subnet is supported."
  }
}

variable default_outbound_access_enabled {
  description = "Enable default outbound internet access (set at create time only)"
  type        = bool
  default     = false
}

variable delegations {
  description = "Subnet delegations"
  type = list(object({
    name = string
    service_delegation = object({
      name = string
    })
  }))
  default = null
}

variable nat_gateway {
  description = "NAT Gateway to associate"
  type = object({
    id = string
  })
  default = null
}

variable network_security_group {
  description = "NSG to associate"
  type = object({
    id = string
  })
  default = null
}

variable private_endpoint_network_policies {
  description = "Network policies for private endpoints: Disabled, Enabled, NetworkSecurityGroupEnabled, RouteTableEnabled"
  type        = string
  default     = "Enabled"
  nullable    = false

  validation {
    condition     = can(regex("^(Disabled|Enabled|NetworkSecurityGroupEnabled|RouteTableEnabled)$", var.private_endpoint_network_policies))
    error_message = "Must be one of: Disabled, Enabled, NetworkSecurityGroupEnabled, RouteTableEnabled."
  }
}

variable private_link_service_network_policies_enabled {
  description = "Enable network policies for private link service (false disables NSG/UDR on PLS traffic)"
  type        = bool
  default     = true
}

variable route_table {
  description = "Route table to associate"
  type = object({
    id = string
  })
  default = null
}

variable service_endpoint_policies {
  description = "Service endpoint policy IDs to associate"
  type = map(object({
    id = string
  }))
  default = null
}

variable service_endpoints_with_location {
  description = "Service endpoints with optional location restrictions"
  type = list(object({
    service   = string
    locations = optional(list(string), ["*"])
  }))
  default = null
}

variable role_assignments {
  description = "Role assignments to create on the subnet"
  type = map(object({
    role_definition_id_or_name             = string
    principal_id                           = string
    description                            = optional(string, null)
    skip_service_principal_aad_check       = optional(bool, false)
    condition                              = optional(string, null)
    condition_version                      = optional(string, null)
    delegated_managed_identity_resource_id = optional(string, null)
    principal_type                         = optional(string, null)
  }))
  default = {}
}

variable retry {
  description = "Retry configuration for azapi resource operations"
  type = object({
    error_message_regex  = optional(list(string), ["AnotherOperationInProgress", "ReferencedResourceNotProvisioned"])
    interval_seconds     = optional(number, 15)
    max_interval_seconds = optional(number, 300)
  })
  default = {}
}

variable timeouts {
  description = "Timeouts for subnet resource operations"
  type = object({
    create = optional(string, "30m")
    read   = optional(string, "5m")
    update = optional(string, "30m")
    delete = optional(string, "30m")
  })
  default = {}
}
