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

  name               = "vnet-basic-eastus2-dev"
  location           = "eastus2"
  vnet_address_space = ["10.0.0.0/16"]

  subnets = {
    pub-web   = ["10.0.0.0/24"]
    priv-app  = ["10.0.1.0/24"]
    priv-data = ["10.0.2.0/24"]
  }

  tags = {
    Environment = "dev"
    Project     = "basic-example"
  }
}

output "vnet_id" {
  value = module.vnet.vnet_id
}

output "subnet_ids" {
  value = module.vnet.subnet_ids
}
