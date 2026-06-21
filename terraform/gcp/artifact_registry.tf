# エージェントのコンテナイメージを置く Artifact Registry（Docker）。
resource "google_artifact_registry_repository" "agent" {
  project       = var.project_id
  location      = var.region
  repository_id = "zuntalk-agent"
  format        = "DOCKER"
  description   = "ZunTalk ずんだもんエージェントのコンテナイメージ"

  depends_on = [google_project_service.services]
}
