terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

module "vnet" {
  source = "../../"

  name               = "vnet-aks-eastus2-prd"
  location           = "eastus2"
  vnet_address_space = ["10.10.0.0/16"]

  subnets = {
    pub-appgw = ["10.10.0.0/24"]
    aks-node  = ["10.10.4.0/22"]
    aks-pod   = ["10.10.8.0/21"]
    priv-data = ["10.10.16.0/24"]
  }

  # Extend AKS service endpoints with EventHub for Kafka
  extra_aks_service_endpoints = ["Microsoft.EventHub"]

  tags = {
    Environment = "prd"
    Project     = "aks-example"
  }
}

output "vnet_id" {
  value = module.vnet.vnet_id
}

output "aks_node_subnet_id" {
  value = module.vnet.subnet_ids["aks-node"]
}

output "aks_pod_subnet_id" {
  value = module.vnet.subnet_ids["aks-pod"]
}

output "appgw_subnet_id" {
  value = module.vnet.subnet_ids["pub-appgw"]
}

output "subnet_configuration" {
  value = module.vnet.subnet_configuration
}
