# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.10.0"
    }
    keycloak = {
      source  = "mrparkers/keycloak"
      version = ">= 4.3.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
}
