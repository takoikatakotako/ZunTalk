resource "google_secret_manager_secret" "this" {
  project   = var.project_id
  secret_id = var.secret_id

  replication {
    user_managed {
      replicas {
        location = var.replication_location
      }
    }
  }
}

resource "google_secret_manager_secret_iam_member" "accessors" {
  for_each = toset(var.accessor_members)

  project   = var.project_id
  secret_id = google_secret_manager_secret.this.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = each.value
}
