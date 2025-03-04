output "admin_upn" {
  value = azuread_user.admin.user_principal_name
}

output "room_upns" {
  value = azuread_user.rooms[*].user_principal_name
}

output "app_client_id" {
  value = azuread_application.bookings_app.application_id
}

output "app_secret" {
  value     = azuread_application_password.bookings_app_secret.value
  sensitive = true
}