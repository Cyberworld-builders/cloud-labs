provider "azurerm" {
  features {}
}

provider "azuread" {
  # Uses credentials from `az login`
}

resource "azurerm_resource_group" "sandbox" {
  name     = "bookings-sandbox-rg"
  location = "eastus"
}

# Azure AD Users (Rooms and Admin)
resource "azuread_user" "admin" {
  user_principal_name = "admin@yourtenant.onmicrosoft.com"
  display_name        = "Sandbox Admin"
  password            = "TempPass123!"
}

resource "azuread_user" "rooms" {
  count               = 5
  user_principal_name = "room${count.index + 1}@yourtenant.onmicrosoft.com"
  display_name        = "Room ${count.index + 1}"
  password            = random_password.room_pass[count.index].result
  mail_nickname       = "room${count.index + 1}"
}

resource "random_password" "room_pass" {
  count  = 5
  length = 16
  special = true
}

# App Registration (Mimic Bookings Service Account)
resource "azuread_application" "bookings_app" {
  display_name = "BookingsTestApp"
}

resource "azuread_service_principal" "bookings_sp" {
  client_id = azuread_application.bookings_app.application_id
}

resource "azuread_application_password" "bookings_app_secret" {
  application_id = azuread_application.bookings_app.application_id
}