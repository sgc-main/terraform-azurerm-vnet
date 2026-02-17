# AKS Example

VNet designed for Azure Kubernetes Service with dedicated node pools, pod CIDR, public ingress, and Application Gateway subnets.

AKS subnets automatically receive extended service endpoints (ContainerRegistry, Storage, KeyVault, Sql).

## Usage

```bash
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

## terraform.tfvars

```hcl
name               = "vnet-aks-eastus2-prd"
location           = "eastus2"
vnet_address_space = "10.10.0.0/16"

subnets = {
  pub-appgw  = ["10.10.0.0/24"]
  aks-node   = ["10.10.4.0/22"]
  aks-pod    = ["10.10.8.0/21"]
  priv-data  = ["10.10.16.0/24"]
}

tags = {
  Environment = "prd"
  Project     = "aks-example"
}
```
