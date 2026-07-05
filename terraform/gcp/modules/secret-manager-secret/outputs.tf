output "secret_id" {
  description = "Secret Manager secret ID."
  value       = google_secret_manager_secret.this.secret_id
}

output "secret_name" {
  description = "Secret Manager secret resource name."
  value       = google_secret_manager_secret.this.name
}
