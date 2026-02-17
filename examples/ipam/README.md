# IPAM Example

Full IPAM-based VNet where both the VNet and subnets receive their address space dynamically from Azure Network Manager IPAM pools — no hardcoded CIDRs.

> **Prerequisite:** An Azure Network Manager with IPAM pools must already exist. The VNet IPAM pool must have sufficient address space for both the VNet and all subnet allocations.

## Key Points

- `vnet_address_space` is **not set** — the VNet gets its CIDR from `ipam_pools`
- `var.subnets` is **not needed** — subnet keys are derived from `subnet_ipam_pools`
- `subnet_ipam_pools` maps each subnet key to its IPAM pool and desired prefix length
- Subnet naming conventions still apply (keys containing `pub`, `aks`, etc. drive auto-classification)

## Usage

```bash
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```
