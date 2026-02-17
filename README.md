# Azure VNet Module

Opinionated Terraform module for deploying Azure Virtual Networks with convention-driven subnet classification, automatic service endpoint wiring, delegation auto-detection, integrated VPN gateway, bi-directional peering, and supporting resources.

## Features

- **Convention-driven subnet classification** — subnet keys are automatically classified as public, private, AKS, or App Gateway based on naming patterns (no extra flags needed)
- **NAT Gateway** — automatically attached to private subnets
- **NSG** — shared across all subnets with declarative rule map
- **Route tables** — separate public and private route tables, with optional Azure Firewall routing
- **Service endpoints** — baseline sets for private and AKS subnets, extensible via variables
- **Service endpoint policies** — auto-wired storage policy for private non-AKS subnets
- **Delegations** — auto-detected from subnet key patterns, overridable per-subnet
- **Private endpoint network policies** — configurable NSG/UDR enforcement on private endpoint traffic
- **Private Link** — opt-in network policy disablement for Private Link Service subnets
- **Supporting resources** — resource group, storage account, user-assigned identity, Log Analytics workspace
- **IPAM support** — full Azure Network Manager IPAM integration for both VNet and subnet address allocation
- **GatewaySubnet** — auto-detected `GatewaySubnet` key with Azure-mandated constraints (no NSG, no NAT, no route table, exact naming)
- **VPN Gateway** — integrated site-to-site VPN with BGP, custom IPsec policies, active-active, and multi-connection support
- **VNet Peering** — bi-directional peering with mirror-forward defaults, supporting full VNet, address-space-scoped, and subnet-scoped modes

## IPAM Support

The module supports Azure Network Manager IPAM pools for dynamic address allocation at both VNet and subnet levels.

### Address Modes

| Mode | VNet Address | Subnet Address | Variables Used |
|---|---|---|---|
| **Traditional** | `vnet_address_space` (explicit CIDRs) | `subnets` (explicit CIDRs) | `vnet_address_space`, `subnets` |
| **Full IPAM** | `ipam_pools` (dynamic) | `subnet_ipam_pools` (dynamic) | `ipam_pools`, `subnet_ipam_pools` |
| **Mixed** | Either | Mix of both | Any combination |

### Subnet Key Merging

Subnet keys are automatically merged from both `var.subnets` and `var.subnet_ipam_pools`. You can define subnets in either or both — the module unions the keys. This means:

- **IPAM-only** — define subnets solely via `subnet_ipam_pools`, no `subnets` variable needed
- **Traditional-only** — define subnets solely via `subnets`, no `subnet_ipam_pools` needed
- **Mixed** — some subnets in `subnets` with explicit CIDRs, others in `subnet_ipam_pools`

### IPAM Precedence

If a subnet key appears in **both** `var.subnets` and `var.subnet_ipam_pools`, **IPAM wins** — the explicit CIDRs from `var.subnets` are silently ignored and the IPAM pool allocation is used. This enables incremental migration from explicit CIDRs to IPAM without needing to remove entries from `var.subnets` first.

### Full IPAM Example

```hcl
module "vnet" {
  source = "./"

  name     = "vnet-myapp-eastus2-dev"
  location = "eastus2"

  ipam_pools = [{ id = "/subscriptions/.../ipamPools/mypool", prefix_length = 16 }]

  subnet_ipam_pools = {
    pub-appgw = [{ pool_id = "/subscriptions/.../ipamPools/mypool", prefix_length = 24 }]
    priv-app  = [{ pool_id = "/subscriptions/.../ipamPools/mypool", prefix_length = 24 }]
    aks-node  = [{ pool_id = "/subscriptions/.../ipamPools/mypool", prefix_length = 22 }]
    aks-pod   = [{ pool_id = "/subscriptions/.../ipamPools/mypool", prefix_length = 21 }]
  }
}
```

> Subnet naming conventions still apply — keys like `pub-appgw` and `aks-node` drive auto-classification regardless of addressing mode.

## Subnet Naming Conventions

Subnet keys in `var.subnets` and/or `var.subnet_ipam_pools` drive automatic behavior:

| Pattern in Key | Classification | Behavior |
|---|---|---|
| `pub`, `appgw`, `gateway` | Public | Outbound access enabled, public route table, no NAT Gateway, no service endpoints |
| `aks`, `node`, `k8s`, `pod` | AKS | Extended service endpoints (ContainerRegistry, Storage, KeyVault, Sql), NAT Gateway |
| `appgw`, `gateway` | App Gateway | Application Gateway delegation (if enabled), no NAT Gateway |
| `func`, `web` | Web | Web/serverFarms delegation (if enabled) |
| `GatewaySubnet` (exact) | Gateway | Named exactly `GatewaySubnet`, no NSG, no NAT, no route table, no service endpoints, no delegations |
| *(anything else)* | Private | NAT Gateway, default service endpoints (Storage, KeyVault), private route table |

> Patterns are case-insensitive and matched with `regex()`. A subnet can match multiple patterns (e.g., `pub-appgw` is both public and App Gateway).

### Application Gateway Subnet Requirements

Subnets with `appgw` or `gateway` in the key are automatically configured for Azure Application Gateway. The module handles the following Azure constraints:

| Requirement | How the module handles it |
|---|---|
| **Delegation** to `Microsoft.Network/applicationGateways` | Auto-applied via `enable_app_gateway_delegation` (default `true`) |
| **No other resources** in the subnet (only App GW + PEs) | Convention-enforced by using a dedicated `appgw`/`gateway` key |
| **No NAT Gateway** | Explicitly excluded via `!is_app_gateway` guard |
| **No UDR** with `0.0.0.0/0` to NVA/firewall | Gets public route table (no firewall route), not private |
| **No service endpoints** | Excluded via `!is_public` check (App GW subnets are public) |
| **Minimum /24** recommended (/26 minimum per Azure docs) | Caller's responsibility when defining address prefixes |

> **NSG note:** The module attaches the shared NSG to all subnets including App Gateway. For App Gateway v2, you **must** add an inbound rule allowing ports `65200-65535` from `GatewayManager` for health probes via `nsg_rules`. See the [Azure docs](https://learn.microsoft.com/en-us/azure/application-gateway/configuration-infrastructure#network-security-groups) for details.

## Usage

```hcl
module "vnet" {
  source = "./"

  name               = "vnet-myapp-eastus2-dev"
  location           = "eastus2"
  vnet_address_space = ["10.0.0.0/16"]

  subnets = {
    pub-appgw   = ["10.0.0.0/24"]
    priv-app    = ["10.0.1.0/24"]
    priv-data   = ["10.0.2.0/24"]
    aks-node    = ["10.0.4.0/22"]
    aks-pod     = ["10.0.8.0/21"]
  }

  tags = {
    Environment = "dev"
    ManagedBy   = "terraform"
  }
}
```

## Resource Naming

All resources follow the pattern: `{prefix}-{region_no_hyphens}-{env}`

| Resource | Name Pattern | Example |
|---|---|---|
| Resource Group | `rg-{name}` | `rg-vnet-myapp-eastus2-dev` |
| VNet | `{name}` | `vnet-myapp-eastus2-dev` |
| Subnet | `{name}-{key}` | `vnet-myapp-eastus2-dev-priv-app` |
| GatewaySubnet | `GatewaySubnet` (exact, no prefix) | `GatewaySubnet` |
| NAT Gateway | `ngw-{name}` | `ngw-vnet-myapp-eastus2-dev` |
| NSG | `nsg-{name}` | `nsg-vnet-myapp-eastus2-dev` |
| Route Table | `rt-{name}-{public\|private}` | `rt-vnet-myapp-eastus2-dev-private` |
| Storage Account | `sa{name_no_hyphens}` | `savnetmyappeastus2dev` |
| Log Analytics | `log-{name}` | `log-vnet-myapp-eastus2-dev` |
| Identity | `id-{name}` | `id-vnet-myapp-eastus2-dev` |

## Private Endpoint Network Policies

Controls whether NSG and UDR rules apply to traffic destined for private endpoints in private subnets. Public subnets always get `Disabled`.

| Value | NSG on PE traffic | UDR on PE traffic | Use case |
|---|:-:|:-:|---|
| `Enabled` | Yes | Yes | Full network control over PE traffic — internal LBs, storage PEs, SQL PEs |
| `Disabled` | No | No | PE traffic bypasses all network controls (legacy default) |
| `NetworkSecurityGroupEnabled` | Yes | No | Restrict PE access via NSG without forcing traffic through a firewall |
| `RouteTableEnabled` | No | Yes | Force PE traffic through a firewall/NVA without NSG restrictions |

Default is `Enabled` — recommended for most deployments. Set at the VNet module level and applied uniformly to all private subnets.

> **Note:** This is separate from `private_link_subnets`, which controls network policies for **Private Link Services** (when you are the provider exposing a service behind a Standard LB). `private_endpoint_network_policies` controls policies for **consuming** private endpoints.

## DNS Private Resolver Subnets

When deploying a hub VNet with an Azure DNS Private Resolver, you need two dedicated subnets — one for the inbound endpoint and one for the outbound endpoint. These subnets have specific Azure requirements:

| Requirement | Detail |
|---|---|
| **Minimum size** | /28 (16 IPs) per endpoint subnet |
| **Delegation** | `Microsoft.Network/dnsResolvers` — must be exclusive |
| **No other resources** | Only the resolver endpoint can reside in the subnet |
| **No NAT Gateway** | Not supported on delegated DNS resolver subnets |
| **No service endpoints** | Not applicable to DNS resolver subnets |

DNS resolver subnets are **not auto-detected** — they require explicit delegation via `subnet_delegations` since they are only needed in hub VNets. The recommended key prefix is `snet-dns-` which classifies them as private subnets:

```hcl
module "hub_vnet" {
  source = "./"

  name               = "vnet-hub-eastus2-prod"
  location           = "eastus2"
  vnet_address_space = ["10.143.0.0/24"]

  subnets = {
    snet-dns-inbound  = ["10.143.0.0/28"]
    snet-dns-outbound = ["10.143.0.16/28"]
  }

  # DNS resolver subnets require explicit delegation
  subnet_delegations = {
    "snet-dns-inbound" = [{
      name = "Microsoft.Network.dnsResolvers"
      service_delegation = {
        name    = "Microsoft.Network/dnsResolvers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }]
    "snet-dns-outbound" = [{
      name = "Microsoft.Network.dnsResolvers"
      service_delegation = {
        name    = "Microsoft.Network/dnsResolvers"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }]
  }

  # Hub-only VNet — typically no NAT or service endpoints needed
  enable_nat_gateway       = false
  enable_service_endpoints = false
}
```

## VPN Gateway Subnet (GatewaySubnet)

When deploying an Azure VPN Gateway or ExpressRoute Gateway, Azure requires a subnet named exactly `GatewaySubnet`. The module auto-detects this key and applies the specific constraints Azure enforces:

| Requirement | How the module handles it |
|---|---|
| **Exact name** `GatewaySubnet` | Subnet is named `GatewaySubnet` literally — not prefixed with `{name}-` |
| **No NSG** | Azure disallows NSG on GatewaySubnet — the module skips NSG attachment |
| **No NAT Gateway** | Excluded from NAT gateway association |
| **No route table** | No public or private route table attached (Azure manages gateway routes) |
| **No service endpoints** | Not applicable — excluded from service endpoint wiring |
| **No delegations** | Delegations are not supported on GatewaySubnet |
| **Minimum /27** | Caller's responsibility — `/27` is the minimum for VPN Gateway, `/26` recommended for ExpressRoute |

GatewaySubnet is **not classified as public or private** — it is excluded from both `public_subnet_ids` and `private_subnet_ids` outputs. Use the dedicated `gateway_subnet_id` output or `subnet_ids["GatewaySubnet"]` to reference it.

```hcl
module "hub_vnet" {
  source = "./"

  name               = "vnet-hub-eastus2-prod"
  location           = "eastus2"
  vnet_address_space = ["10.100.0.0/16"]

  subnets = {
    GatewaySubnet     = ["10.100.0.64/27"]    # VPN/ExpressRoute gateway
    snet-dns-inbound  = ["10.100.0.0/28"]     # DNS resolver
    snet-dns-outbound = ["10.100.0.16/28"]    # DNS resolver
    priv-app          = ["10.100.1.0/24"]
  }

  # Enable the integrated VPN gateway (see VPN Gateway section below)
  enable_vpn_gateway = true

  vpn_connections = {
    to-datacenter = {
      peer_ip_address = "198.51.100.1"
      shared_key      = "MySecret!"
      address_space   = ["192.168.0.0/16"]
    }
  }
}

# Outputs
gateway_subnet_id = module.hub_vnet.gateway_subnet_id
vpn_gateway_ip    = module.hub_vnet.vpn_gateway_public_ip
```

> **Note:** The key is case-insensitive for detection (`gatewaysubnet`, `GatewaySubnet`, `GATEWAYSUBNET` all work), but the resulting Azure subnet name is always the exact string `GatewaySubnet` as required by the platform.

## VPN Gateway

The module includes an integrated VPN gateway submodule that creates all the resources needed for site-to-site VPN connectivity. When enabled, it provisions:

- **Public IP(s)** — Standard SKU, static allocation (2 if active-active)
- **Virtual Network Gateway** — VPN type, configurable SKU, generation, and BGP
- **Local Network Gateways** — one per entry in `vpn_connections`, representing each remote site
- **VPN Connections** — IPsec connections with optional custom IPsec/IKE policies

### Requirements

- `GatewaySubnet` must exist in the `subnets` map (the module will error if it doesn't when VPN is enabled)
- Minimum `/27` subnet, `/26` recommended for active-active

### Basic VPN Example

```hcl
module "hub_vnet" {
  source = "./"

  name               = "vnet-hub-eastus2-prod"
  location           = "eastus2"
  vnet_address_space = ["10.100.0.0/16"]

  subnets = {
    GatewaySubnet = ["10.100.0.64/27"]
    priv-app      = ["10.100.1.0/24"]
  }

  enable_vpn_gateway = true
  vpn_gateway_sku    = "VpnGw2"

  vpn_connections = {
    to-aws = {
      peer_ip_address = "203.0.113.1"
      shared_key      = "SuperSecret123!"
      address_space   = ["10.200.0.0/16", "172.16.0.0/12"]
    }
  }
}
```

### VPN with BGP Example

```hcl
module "hub_vnet" {
  source = "./"

  name               = "vnet-hub-eastus2-prod"
  location           = "eastus2"
  vnet_address_space = ["10.100.0.0/16"]

  subnets = {
    GatewaySubnet = ["10.100.0.64/27"]
    priv-app      = ["10.100.1.0/24"]
  }

  enable_vpn_gateway     = true
  vpn_gateway_enable_bgp = true
  vpn_gateway_bgp_asn    = 65100

  vpn_connections = {
    to-aws-primary = {
      peer_ip_address     = "203.0.113.1"
      shared_key          = "TunnelPrimary!"
      enable_bgp          = true
      bgp_asn             = 64512
      bgp_peering_address = "169.254.21.1"
    }
    to-aws-secondary = {
      peer_ip_address     = "203.0.113.2"
      shared_key          = "TunnelSecondary!"
      enable_bgp          = true
      bgp_asn             = 64512
      bgp_peering_address = "169.254.22.1"
    }
  }
}
```

### VPN with Custom IPsec Policy

```hcl
vpn_connections = {
  to-datacenter = {
    peer_ip_address = "198.51.100.1"
    shared_key      = "DCSecret!"
    address_space   = ["192.168.0.0/16"]
    ipsec_policy = {
      ike_encryption   = "AES256"
      ike_integrity    = "SHA256"
      dh_group         = "DHGroup14"
      ipsec_encryption = "AES256"
      ipsec_integrity  = "SHA256"
      pfs_group        = "PFS14"
      sa_lifetime      = 3600
    }
  }
}
```

### VPN Gateway Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `enable_vpn_gateway` | Create VPN gateway and connections | `bool` | `false` |
| `vpn_gateway_sku` | Gateway SKU (VpnGw1–VpnGw5, optionally with AZ suffix) | `string` | `"VpnGw2"` |
| `vpn_gateway_generation` | Gateway generation (Generation1 or Generation2) | `string` | `"Generation2"` |
| `vpn_gateway_type` | VPN type (RouteBased or PolicyBased) | `string` | `"RouteBased"` |
| `vpn_gateway_active_active` | Enable active-active mode (2 public IPs) | `bool` | `false` |
| `vpn_gateway_enable_bgp` | Enable BGP on the gateway | `bool` | `true` |
| `vpn_gateway_bgp_asn` | BGP Autonomous System Number | `number` | `65515` |

### VPN Connection Inputs

Each entry in `vpn_connections` accepts:

| Name | Description | Type | Default |
|---|---|---|---|
| `peer_ip_address` | Remote gateway public IP | `string` | — |
| `shared_key` | IPsec pre-shared key | `string` | — |
| `address_space` | Remote CIDRs (static routing) | `list(string)` | `[]` |
| `enable_bgp` | Use BGP for this connection | `bool` | `false` |
| `bgp_asn` | Remote BGP ASN | `number` | `null` |
| `bgp_peering_address` | Remote BGP peer address | `string` | `null` |
| `ipsec_policy` | Custom IPsec/IKE parameters (null = Azure defaults) | `object` | `null` |
| `connection_protocol` | IKEv1 or IKEv2 | `string` | `"IKEv2"` |
| `dpd_timeout_seconds` | Dead peer detection timeout | `number` | `45` |
| `use_policy_based_traffic_selectors` | Required for some on-prem devices | `bool` | `false` |
| `routing_weight` | Route priority (lower = preferred) | `number` | `0` |
| `tags` | Per-connection tags (merged with module tags) | `map(string)` | `{}` |

## Requirements

| Name | Version |
|---|---|
| terraform | >= 1.9, < 2.0 |
| azurerm | ~> 4.0 |
| azapi | ~> 2.5 |

## Providers

| Name | Version |
|---|---|
| azurerm | ~> 4.0 |
| azapi | ~> 2.5 |

## Modules

| Name | Source | Version |
|---|---|---|
| vnet | ./modules/vnet | local |
| subnet | ./modules/subnet | local |
| peering | ./modules/peering | local |
| vpn | ./modules/vpn | local |

## Inputs

| Name | Description | Type | Default | Required |
|---|---|---|---|---|
| `name` | Resource name base (used as prefix for all child resources) | `string` | — | yes |
| `location` | Azure region for deployment | `string` | — | yes |
| `vnet_address_space` | VNet address space CIDRs (mutually exclusive with `ipam_pools`) | `set(string)` | `null` | no |
| `ipam_pools` | IPAM pool allocation (mutually exclusive with `vnet_address_space`) | `list(object({id, prefix_length}))` | `null` | no |
| `subnets` | Map of subnet key → address prefixes. Keys drive auto-classification. | `map(list(string))` | `{}` | no |
| `subnet_ipam_pools` | Per-subnet IPAM pool allocations (IPAM takes precedence over `subnets`) | `map(list(object({pool_id, prefix_length})))` | `{}` | no |
| `tags` | Resource tags | `map(string)` | `{}` | no |
| `enable_nat_gateway` | Enable NAT Gateway for private subnets | `bool` | `true` | no |
| `enable_nsg` | Enable Network Security Group | `bool` | `true` | no |
| `enable_route_table` | Enable Route Tables | `bool` | `true` | no |
| `enable_service_endpoints` | Enable Service Endpoints and Storage Account | `bool` | `true` | no |
| `enable_log_analytics_workspace` | Create a Log Analytics Workspace in the VNet resource group | `bool` | `false` | no |
| `enable_managed_identity` | Create a User Assigned Managed Identity in the VNet resource group | `bool` | `false` | no |
| `enable_web_delegation` | Enable Web/serverFarms delegation for func/web subnets | `bool` | `true` | no |
| `enable_app_gateway_delegation` | Enable App Gateway delegation for appgw/gateway subnets | `bool` | `true` | no |
| `extra_service_endpoints` | Additional service endpoints for private non-AKS subnets | `list(string)` | `[]` | no |
| `extra_aks_service_endpoints` | Additional service endpoints for AKS subnets | `list(string)` | `[]` | no |
| `nsg_rules` | Map of NSG security rules (key = rule name) | `map(object({...}))` | `{}` | no |
| `use_azure_firewall` | Route private subnet traffic through Azure Firewall | `bool` | `false` | no |
| `azure_firewall_private_ip` | Azure Firewall private IP (required if `use_azure_firewall = true`) | `string` | `""` | no |
| `private_endpoint_network_policies` | NSG/UDR enforcement on PE traffic for private subnets | `string` | `"Enabled"` | no |
| `private_link_subnets` | Subnet keys that host Private Link Services (disables network policies) | `list(string)` | `[]` | no |
| `subnet_delegations` | Explicit subnet delegations (overrides auto-detected) | `map(list(object({...})))` | `{}` | no |
| `peerings` | Map of VNet peering configurations (see [Peering Inputs](#peering-inputs)) | `map(object({...}))` | `{}` | no |
| `enable_vpn_gateway` | Create VPN gateway and connections | `bool` | `false` | no |
| `vpn_gateway_sku` | Gateway SKU (VpnGw1–VpnGw5, optionally with AZ suffix) | `string` | `"VpnGw2"` | no |
| `vpn_gateway_generation` | Gateway generation (Generation1 or Generation2) | `string` | `"Generation2"` | no |
| `vpn_gateway_type` | VPN type (RouteBased or PolicyBased) | `string` | `"RouteBased"` | no |
| `vpn_gateway_active_active` | Enable active-active mode (2 public IPs) | `bool` | `false` | no |
| `vpn_gateway_enable_bgp` | Enable BGP on the gateway | `bool` | `true` | no |
| `vpn_gateway_bgp_asn` | BGP Autonomous System Number | `number` | `65515` | no |
| `vpn_connections` | Map of VPN connection configurations (see [VPN Connection Inputs](#vpn-connection-inputs)) | `map(object({...}))` | `{}` | no |

### NSG Rules Shape

```hcl
nsg_rules = {
  "allow-https-inbound" = {
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
    description                = "Allow HTTPS inbound"
  }
}
```

### Private Endpoint Network Policies Example

```hcl
module "vnet" {
  source = "./"

  # ...

  # Only NSG controls PE traffic, UDR is bypassed (no firewall inspection on PE)
  private_endpoint_network_policies = "NetworkSecurityGroupEnabled"
}
```

### Subnet Delegations Shape

```hcl
subnet_delegations = {
  "priv-sql" = [{
    name = "Microsoft.Sql.managedInstances"
    service_delegation = {
      name = "Microsoft.Sql/managedInstances"
    }
  }]
}
```

## Outputs

| Name | Description |
|---|---|
| `vnet_id` | Virtual Network ID |
| `vnet_name` | Virtual Network name |
| `vnet_address_spaces` | Virtual Network address spaces |
| `subnet_ids` | Map of all subnet keys to resource IDs |
| `public_subnet_ids` | Map of public subnet IDs |
| `private_subnet_ids` | Map of private subnet IDs |
| `gateway_subnet_id` | GatewaySubnet resource ID (null if not defined) |
| `resource_group_name` | Resource group name |
| `resource_group_id` | Resource group ID |
| `nat_gateway_id` | NAT Gateway ID (null if disabled) |
| `nsg_id` | NSG ID (null if disabled) |
| `log_analytics_workspace_id` | Log Analytics Workspace ID (null if disabled) |
| `user_assigned_identity_id` | User Assigned Identity ID (null if disabled) |
| `user_assigned_identity_principal_id` | User Assigned Identity Principal ID (null if disabled) |
| `subnet_configuration` | Computed subnet config showing classification and feature flags |
| `peering_ids` | Map of peering keys to forward peering resource IDs |
| `peering_reverse_ids` | Map of peering keys to reverse peering resource IDs (null if not created) |
| `vpn_gateway_id` | VPN Gateway resource ID (null if VPN disabled) |
| `vpn_gateway_public_ip` | Primary public IP of the VPN gateway (null if VPN disabled) |
| `vpn_gateway_secondary_public_ip` | Secondary public IP (active-active only, null otherwise) |
| `vpn_gateway_bgp_settings` | BGP settings of the VPN gateway (null if VPN or BGP disabled) |
| `vpn_connection_ids` | Map of connection key → VPN connection resource ID |
| `vpn_local_network_gateway_ids` | Map of connection key → Local Network Gateway resource ID |

## VNet Peering

The module supports bi-directional VNet peering with three scoping modes and a **mirror-forward** pattern for reverse peering settings.

### Mirror-Forward Defaults

When `create_reverse_peering = true`, all `reverse_*` properties default to `null` — which means they **mirror the corresponding forward setting**. You only need to set `reverse_*` properties when the reverse peering requires different values (e.g., `use_remote_gateways` on only one side).

### Peering Modes

| Mode | `peer_complete_vnets` | Additional Inputs | Description |
|---|---|---|---|
| **Full VNet** | `true` (default) | None | Peers the entire address space of both VNets |
| **Address-space scoped** | `false` | `local_peered_address_spaces`, `remote_peered_address_spaces` | Peers only specified CIDR ranges |
| **Subnet scoped** | `false` | `local_peered_subnets`, `remote_peered_subnets` | Peers only specified subnets by name |

> For address-space and subnet modes, the reverse peering automatically **swaps local and remote** — you don't need to manually reverse them.

### Bi-Directional Peering Example

```hcl
module "vnet" {
  source = "./"

  name               = "vnet-myapp-eastus2-dev"
  location           = "eastus2"
  vnet_address_space = ["10.0.0.0/16"]

  subnets = {
    priv-app  = ["10.0.1.0/24"]
    priv-data = ["10.0.2.0/24"]
  }

  peerings = {
    to-hub = {
      remote_virtual_network_resource_id = "/subscriptions/.../virtualNetworks/vnet-hub"
      allow_forwarded_traffic            = true
      allow_gateway_transit              = false
      use_remote_gateways                = true

      # Reverse peering is created with identical settings (mirrored),
      # except use_remote_gateways which we override for the hub side
      create_reverse_peering  = true
      reverse_name            = "peer-hub-to-spoke"
      reverse_use_remote_gateways = false
    }
  }
}
```

### Address-Space Scoped Peering Example

```hcl
peerings = {
  to-shared = {
    remote_virtual_network_resource_id = "/subscriptions/.../virtualNetworks/vnet-shared"
    peer_complete_vnets                = false

    local_peered_address_spaces  = [{ address_prefix = "10.0.1.0/24" }]
    remote_peered_address_spaces = [{ address_prefix = "10.1.0.0/24" }]

    # Reverse auto-swaps: remote sees 10.1.0.0/24 as local and 10.0.1.0/24 as remote
    create_reverse_peering = true
    reverse_name           = "peer-shared-to-app"
  }
}
```

### Subnet-Scoped Peering Example

```hcl
peerings = {
  to-data = {
    remote_virtual_network_resource_id = "/subscriptions/.../virtualNetworks/vnet-data"
    peer_complete_vnets                = false

    local_peered_subnets  = [{ subnet_name = "priv-app" }]
    remote_peered_subnets = [{ subnet_name = "priv-db" }]

    create_reverse_peering = true
    reverse_name           = "peer-data-to-app"
  }
}
```

### Peering Inputs

| Name | Description | Type | Default |
|---|---|---|---|
| `remote_virtual_network_resource_id` | Remote VNet resource ID | `string` | — |
| `allow_forwarded_traffic` | Allow forwarded traffic | `bool` | `false` |
| `allow_gateway_transit` | Allow gateway transit | `bool` | `false` |
| `allow_virtual_network_access` | Allow VNet access | `bool` | `true` |
| `do_not_verify_remote_gateways` | Skip remote gateway verification | `bool` | `false` |
| `enable_only_ipv6_peering` | IPv6-only peering | `bool` | `false` |
| `peer_complete_vnets` | Peer entire VNets (false = scoped mode) | `bool` | `true` |
| `use_remote_gateways` | Use remote gateways | `bool` | `false` |
| `local_peered_address_spaces` | Local CIDR scopes (scoped mode) | `list(object)` | `null` |
| `remote_peered_address_spaces` | Remote CIDR scopes (scoped mode) | `list(object)` | `null` |
| `local_peered_subnets` | Local subnet scopes (scoped mode) | `list(object)` | `null` |
| `remote_peered_subnets` | Remote subnet scopes (scoped mode) | `list(object)` | `null` |
| `create_reverse_peering` | Create reverse peering | `bool` | `false` |
| `reverse_name` | Reverse peering name | `string` | `null` |
| `reverse_*` | Override any forward property for reverse (null = mirror forward) | varies | `null` |
| `sync_remote_address_space_enabled` | Enable address space sync updates | `bool` | `false` |
| `sync_remote_address_space_triggers` | Trigger value for address space sync | `any` | `null` |

## Examples

- [Basic](./examples/basic/) — Minimal VNet with public and private subnets
- [AKS](./examples/aks/) — AKS-oriented VNet with node, pod, and ingress subnets
- [Complete](./examples/complete/) — All features: NSG rules, firewall routing, delegations, Private Link
- [IPAM](./examples/ipam/) — Full IPAM-based VNet and subnet allocation from Azure Network Manager
- [Peering](./examples/peering/) — Full VNet, address-space-scoped, and subnet-scoped peering scenarios
- [VPN](./examples/vpn/) — Site-to-site VPN: static routing, BGP, custom IPsec, hub-spoke gateway transit

## License

Proprietary — internal use only.
