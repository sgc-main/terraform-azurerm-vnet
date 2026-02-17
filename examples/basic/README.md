# Basic Example

Minimal VNet with one public and two private subnets. All defaults enabled (NAT Gateway, NSG, route tables, service endpoints).

## Usage

```bash
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```

## terraform.tfvars

```hcl
name               = "vnet-basic-eastus2-dev"
location           = "eastus2"
vnet_address_space = "10.0.0.0/16"

subnets = {
  pub-web   = ["10.0.0.0/24"]
  priv-app  = ["10.0.1.0/24"]
  priv-data = ["10.0.2.0/24"]
}

tags = {
  Environment = "dev"
  Project     = "basic-example"
}
```
