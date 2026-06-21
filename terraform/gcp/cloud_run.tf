# Cloud Run の実行用サービスアカウント。
resource "google_service_account" "runtime" {
  project      = var.project_id
  account_id   = "agent-runtime"
  display_name = "ZunTalk Agent Cloud Run runtime"
}

# 実行SAに Vertex AI 呼び出し権限を付与（キーレスで Gemini を叩く）。
resource "google_project_iam_member" "runtime_vertex" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${google_service_account.runtime.email}"
}

# エージェント本体の Cloud Run サービス。
resource "google_cloud_run_v2_service" "agent" {
  project  = var.project_id
  name     = "zuntalk-agent"
  location = var.region

  # ハッカソン用途のため誤操作時に消せるよう保護は無効。
  deletion_protection = false

  template {
    service_account = google_service_account.runtime.email

    containers {
      image = var.image

      ports {
        container_port = 8080
      }

      env {
        name  = "GCP_PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "VERTEX_LOCATION"
        value = var.vertex_location
      }
      env {
        name  = "GEMINI_MODEL"
        value = var.gemini_model
      }
      # APIキーは Secret Manager から注入する。
      env {
        name = "AGENT_API_KEY"
        value_source {
          secret_key_ref {
            secret  = google_secret_manager_secret.api_key.secret_id
            version = "latest"
          }
        }
      }
    }
  }

  # 実イメージは CI(agent-deploy.yml)が更新するため、TF では image 差分を無視する。
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
    ]
  }

  depends_on = [
    google_project_service.services,
    google_secret_manager_secret_iam_member.runtime_api_key,
  ]
}

# パブリック公開（誰でも invoke 可）。実際の保護は Go の X-Api-Key 検証で行う。
resource "google_cloud_run_v2_service_iam_member" "public" {
  project  = var.project_id
  location = var.region
  name     = google_cloud_run_v2_service.agent.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}
