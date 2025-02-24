resource "azurerm_resource_group" "rg_sandbox" {
  name     = "rg-sandbox-utopia-dev"
  location = "West US 2"  # Adjust region as needed
}

resource "azurerm_key_vault" "kv_sandbox" {
  name                        = "utopiadevkv"
  location                    = azurerm_resource_group.rg_sandbox.location
  resource_group_name         = azurerm_resource_group.rg_sandbox.name
  tenant_id                   = var.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = var.tenant_id
    object_id = azurerm_user_assigned_identity.aks_identity.principal_id  # Link to AKS identity below

    secret_permissions = [
      "Get",
      "List",
      "Set"
    ]
  }

  # Add access policy for your user account
  access_policy {
    tenant_id = var.tenant_id
    object_id = var.user_id

    secret_permissions = [
      "Get",
      "List",
      "Set",
      "Delete",
      "Purge"
    ]
  }
}

# Add a sample secret to the Key Vault (similar to tyson-testing)
resource "azurerm_key_vault_secret" "test_secret" {
  name         = "tyson-testing"
  value        = "sandbox-secret-value"
  key_vault_id = azurerm_key_vault.kv_sandbox.id
}

resource "azurerm_user_assigned_identity" "aks_identity" {
  name                = "aks-sandbox-identity"
  resource_group_name = azurerm_resource_group.rg_sandbox.name
  location            = azurerm_resource_group.rg_sandbox.location
}

resource "azurerm_kubernetes_cluster" "aks_sandbox" {
  name                = "utopia-akscluster-sandbox"
  location            = azurerm_resource_group.rg_sandbox.location
  resource_group_name = azurerm_resource_group.rg_sandbox.name
  dns_prefix          = "utopia-sandbox"

  default_node_pool {
    name       = "agentpool"
    node_count = 1
    vm_size    = "Standard_DS2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"  # Use Azure CNI for network integration
  }
}

resource "azurerm_role_assignment" "kv_access" {
  scope                = azurerm_key_vault.kv_sandbox.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_kubernetes_cluster.aks_sandbox.identity[0].principal_id  # For system-assigned
  # or principal_id = azurerm_user_assigned_identity.aks_identity.principal_id  # For user-assigned
}