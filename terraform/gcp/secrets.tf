# /agent を保護する共有 APIキーを入れる箱。
# 値（バージョン）は Terraform では管理せず、out-of-band で投入する:
#   printf '%s' "$(openssl rand -hex 32)" | \
#     gcloud secrets versions add agent-api-key --data-file=- --project=sandbox-492513
resource "google_secret_manager_secret" "api_key" {
  project   = var.project_id
  secret_id = "agent-api-key"

  # コスト最小化のため単一リージョンに保管。
  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }

  depends_on = [google_project_service.services]
}

# Cloud Run の実行SAがAPIキーを読めるようにする。
resource "google_secret_manager_secret_iam_member" "runtime_api_key" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.api_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.runtime.email}"
}
