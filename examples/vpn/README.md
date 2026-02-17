# VPN Gateway Example

Demonstrates the VNet module's integrated VPN gateway with four connection scenarios and hub-spoke gateway transit.

## What This Creates

### Hub VNet (`vnet-hub-eastus2-prod`)
- **GatewaySubnet** — `/27` subnet for the VPN gateway
- **VPN Gateway** — VpnGw2 SKU with BGP enabled
- **4 VPN connections:**
  1. `to-datacenter` — static routing with custom IPsec policy
  2. `to-aws-primary` — BGP-enabled tunnel to AWS (tunnel 1)
  3. `to-aws-secondary` — BGP-enabled tunnel to AWS (tunnel 2, redundancy)
  4. `to-branch` — simple static tunnel using Azure IPsec defaults
- **Peering** — hub-to-spoke with `allow_gateway_transit` so the spoke can reach remote sites through the hub's VPN gateway

### Spoke VNet (`vnet-spoke-eastus2-prod`)
- Private subnets only
- Peered back to hub with `use_remote_gateways = true`

## Usage

```bash
terraform init
terraform plan -var 'vpn_shared_key_dc=MyDCKey!' \
               -var 'vpn_shared_key_aws=MyAWSKey!' \
               -var 'vpn_shared_key_branch=MyBranchKey!'
```

## Key Outputs

| Output | Description |
|---|---|
| `vpn_gateway_public_ip` | Configure this IP as the peer on your remote devices |
| `vpn_gateway_bgp_settings` | ASN + peering addresses for BGP tunnel configuration |
| `vpn_connection_ids` | Map of connection names to Azure resource IDs |
