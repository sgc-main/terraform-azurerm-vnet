# Azure VNet Peering Submodule

Internal submodule for managing Azure Virtual Network peerings. Supports full VNet, address-space-scoped, and subnet-scoped peering with optional bi-directional (reverse) peering and remote address space sync.

## Design

This submodule uses a single `azapi_resource` with `for_each` over a locals map containing `"forward"` and optionally `"reverse"` entries. The peering body is constructed dynamically with `merge()` — address-space and subnet scope properties are conditionally included only when the peering is scoped (`peer_complete_vnets = false`).

| Resource | Count | Purpose |
|---|---|---|
| `azapi_resource.peering` | 1–2 | Forward + optional reverse peering |
| `azapi_update_resource.sync` | 0–2 | Address space sync (when enabled) |
| `terraform_data.sync_remote_address_space_triggers` | 0–1 | Sync trigger |

### Mirror-Forward Pattern

The peering resource name is derived from the map key (`each.key`) rather than a separate `name` property. This means creating a reverse peering with identical settings only requires `create_reverse_peering = true` and `reverse_name`. Override individual `reverse_*` properties only when the reverse side needs different values.

For address-space and subnet scoped peerings, the reverse automatically **swaps local and remote** — you don't need to manually reverse them.

### Peering Modes

| Mode | `peer_complete_vnets` | Body Properties Added |
|---|---|---|
| Full VNet | `true` (default) | None — base properties only |
| Address-space | `false` | `localAddressSpace`, `remoteAddressSpace` |
| Subnet | `false` | `localSubnetNames`, `remoteSubnetNames` |

## Usage

This submodule is called by the parent VNet module via `peering.tf` and is not intended to be used standalone.

```hcl
module "peering" {
  source   = "./modules/peering"
  for_each = var.peerings

  name                      = each.key
  parent_id                 = module.vnet.resource_id
  remote_virtual_network_id = each.value.remote_virtual_network_resource_id

  allow_forwarded_traffic = each.value.allow_forwarded_traffic
  # ... forward settings ...

  create_reverse_peering = each.value.create_reverse_peering
  reverse_name           = each.value.reverse_name
  # ... reverse settings (null = mirror forward) ...

  depends_on = [module.subnet]
}
```

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.9, < 2.0 |
| azapi | ~> 2.5 |

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `name` | Forward peering name | `string` | — | yes |
| `parent_id` | Local VNet resource ID | `string` | — | yes |
| `remote_virtual_network_id` | Remote VNet resource ID | `string` | — | yes |
| `allow_forwarded_traffic` | Allow forwarded traffic | `bool` | `false` | no |
| `allow_gateway_transit` | Allow gateway transit | `bool` | `false` | no |
| `allow_virtual_network_access` | Allow VNet access | `bool` | `true` | no |
| `do_not_verify_remote_gateways` | Skip remote gateway verification | `bool` | `false` | no |
| `enable_only_ipv6_peering` | IPv6-only peering | `bool` | `false` | no |
| `peer_complete_vnets` | Peer entire VNets (false = scoped mode) | `bool` | `true` | no |
| `use_remote_gateways` | Use remote gateways | `bool` | `false` | no |
| `local_peered_address_spaces` | Local CIDR scopes (scoped mode) | `list(object)` | `[]` | no |
| `remote_peered_address_spaces` | Remote CIDR scopes (scoped mode) | `list(object)` | `[]` | no |
| `local_peered_subnets` | Local subnet scopes (scoped mode) | `list(object)` | `[]` | no |
| `remote_peered_subnets` | Remote subnet scopes (scoped mode) | `list(object)` | `[]` | no |
| `create_reverse_peering` | Create reverse peering | `bool` | `false` | no |
| `reverse_name` | Reverse peering name | `string` | `null` | no |
| `reverse_*` | Override any forward property for reverse (null = mirror) | varies | `null` | no |
| `sync_remote_address_space_enabled` | Enable address space sync | `bool` | `false` | no |
| `sync_remote_address_space_triggers` | Trigger for sync (required if enabled) | `any` | `null` | no |
| `retry` | Retry configuration | `object` | `{}` | no |
| `timeouts` | Timeout configuration | `object` | `{}` | no |

## Outputs

| Name | Description |
|---|---|
| `name` | Forward peering name |
| `resource_id` | Forward peering resource ID |
| `reverse_name` | Reverse peering name (null if not created) |
| `reverse_resource_id` | Reverse peering resource ID (null if not created) |
