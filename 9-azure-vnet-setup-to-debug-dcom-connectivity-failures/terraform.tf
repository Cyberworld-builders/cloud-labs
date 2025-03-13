# Terraform configuration
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }

  # backend "azurerm" {
  #   resource_group_name  = "az-cyberworld-sandbox-ops"
  #   storage_account_name = "cyberworldsandboxtfstate"
  #   container_name       = "terraform-state"
  #   key                  = "lenel-dcom-troubleshooting.tfstate"
  # }
}

# Configure the Azure provider to use the current logged-in user
provider "azurerm" {
  features {}
  # Subscription ID will be set via variable (no explicit credentials, uses az login context)
  subscription_id = var.subscription_id
}

# Variables
variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "location" {
  description = "Azure region for deployment"
  default     = "East US" # Adjust as needed
}

# New Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "lenel-dcom-troubleshooting-rg"
  location = var.location
}