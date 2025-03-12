output "nvr_public_ip" {
  value = azurerm_public_ip.nvr_public_ip.ip_address
}

output "app_public_ip" {
  value = azurerm_public_ip.app_public_ip.ip_address
}
