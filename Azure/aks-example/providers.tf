provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "azuread" {
  # Use default configuration or specify tenant_id if needed
}