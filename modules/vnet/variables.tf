variable name {
  description = "Virtual network name"
  type        = string
}

variable location {
  description = "Azure region"
  type        = string
  nullable    = false
}

variable parent_id {
  description = "Resource group ID"
  type        = string

  validation {
    condition     = can(regex("^/subscriptions/[^/]+/resourceGroups/[^/]+$", var.parent_id))
    error_message = "Must be a valid resource group ID."
  }
}

variable address_space {
  description = "VNet address space CIDRs. Mutually exclusive with ipam_pools."
  type        = set(string)
  default     = null

  validation {
    condition     = (var.address_space != null && var.ipam_pools == null) || (var.address_space == null && var.ipam_pools != null)
    error_message = "Either address_space or ipam_pools must be specified, but not both."
  }
}

variable ipam_pools {
  description = "IPAM pool allocations for VNet address space. Mutually exclusive with address_space."
  type = list(object({
    id            = string
    prefix_length = number
  }))
  default = null

  validation {
    condition = var.ipam_pools == null || alltrue([
      for pool in var.ipam_pools : can(regex("^\\/subscriptions\\/[\\w-]+\\/resourceGroups\\/[\\w-]+\\/providers\\/Microsoft\\.Network\\/networkManagers\\/[\\w-]+\\/ipamPools\\/[\\w-]+$", pool.id))
    ])
    error_message = "IPAM pool ID must be a valid ipamPools resource ID."
  }
  validation {
    condition = var.ipam_pools == null || alltrue([
      for pool in var.ipam_pools : (pool.prefix_length >= 2 && pool.prefix_length <= 29) || (pool.prefix_length >= 48 && pool.prefix_length <= 64)
    ])
    error_message = "Prefix length must be between 2 and 29 for IPv4 or 48 and 64 for IPv6."
  }
  validation {
    condition = var.ipam_pools == null || length([
      for pool in var.ipam_pools : pool if pool.prefix_length >= 2 && pool.prefix_length <= 29
    ]) <= 1
    error_message = "Only one IPv4 pool can be specified."
  }
  validation {
    condition = var.ipam_pools == null || length([
      for pool in var.ipam_pools : pool if pool.prefix_length >= 48 && pool.prefix_length <= 64
    ]) <= 1
    error_message = "Only one IPv6 pool can be specified."
  }
}

variable tags {
  description = "Resource tags"
  type        = map(string)
  default     = null
}

variable bgp_community {
  description = "BGP community value to send to the virtual network gateway"
  type        = string
  default     = null
}

variable ddos_protection_plan {
  description = "DDoS Protection Plan configuration (id and enable flag)"
  type = object({
    id     = string
    enable = bool
  })
  default = null
}

variable dns_servers {
  description = "Custom DNS server IPs for the VNet"
  type = object({
    dns_servers = list(string)
  })
  default = null
}

variable enable_vm_protection {
  description = "Enable VM Protection for the virtual network"
  type        = bool
  default     = false
}

variable encryption {
  description = "VNet encryption settings (enforcement: AllowUnencrypted or DropUnencrypted)"
  type = object({
    enabled     = bool
    enforcement = string
  })
  default = null

  validation {
    condition     = var.encryption != null ? contains(["AllowUnencrypted", "DropUnencrypted"], var.encryption.enforcement) : true
    error_message = "Encryption enforcement must be one of: AllowUnencrypted, DropUnencrypted."
  }
}

variable extended_location {
  description = "Extended location (Edge Zone) for the virtual network"
  type = object({
    name = string
    type = string
  })
  default = null

  validation {
    condition     = var.extended_location != null ? var.extended_location.type == "EdgeZone" : true
    error_message = "Extended location type must be EdgeZone."
  }
}

variable flow_timeout_in_minutes {
  description = "Flow timeout in minutes for the virtual network"
  type        = number
  default     = null
}

variable lock {
  description = "Resource lock configuration (kind: CanNotDelete or ReadOnly)"
  type = object({
    kind = string
    name = optional(string, null)
  })
  default = null

  validation {
    condition     = var.lock != null ? contains(["CanNotDelete", "ReadOnly"], var.lock.kind) : true
    error_message = "Lock kind must be CanNotDelete or ReadOnly."
  }
}

variable role_assignments {
  description = "Role assignments to create on the VNet"
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

variable diagnostic_settings {
  description = "Diagnostic settings for the VNet (Log Analytics, Storage, Event Hub, or Marketplace partner)"
  type = map(object({
    name                                     = optional(string, null)
    log_categories                           = optional(set(string), [])
    log_groups                               = optional(set(string), ["allLogs"])
    metric_categories                        = optional(set(string), ["AllMetrics"])
    log_analytics_destination_type           = optional(string, "Dedicated")
    workspace_resource_id                    = optional(string, null)
    storage_account_resource_id              = optional(string, null)
    event_hub_authorization_rule_resource_id = optional(string, null)
    event_hub_name                           = optional(string, null)
    marketplace_partner_resource_id          = optional(string, null)
  }))
  default = {}

  validation {
    condition     = alltrue([for _, v in var.diagnostic_settings : contains(["Dedicated", "AzureDiagnostics"], v.log_analytics_destination_type)])
    error_message = "Log analytics destination type must be Dedicated or AzureDiagnostics."
  }
  validation {
    condition = alltrue([
      for _, v in var.diagnostic_settings :
      v.workspace_resource_id != null || v.storage_account_resource_id != null || v.event_hub_authorization_rule_resource_id != null || v.marketplace_partner_resource_id != null
    ])
    error_message = "At least one destination (workspace, storage, event hub, or marketplace partner) must be set."
  }
}

variable retry {
  description = "Retry configuration for azapi resource operations"
  type = object({
    error_message_regex  = optional(list(string), ["ReferencedResourceNotProvisioned"])
    interval_seconds     = optional(number, 10)
    max_interval_seconds = optional(number, 180)
  })
  default = {}
}

variable timeouts {
  description = "Timeouts for VNet resource operations"
  type = object({
    create = optional(string, "30m")
    read   = optional(string, "5m")
    update = optional(string, "30m")
    delete = optional(string, "30m")
  })
  default = {}
}
