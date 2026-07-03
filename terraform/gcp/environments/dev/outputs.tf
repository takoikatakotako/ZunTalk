output "api_key_secret_id" {
  description = "Agent API key を格納する Secret Manager secret ID。"
  value       = module.agent_api_key.secret_id
}

output "artifact_registry_repo" {
  description = "イメージを push する Artifact Registry リポジトリ（host/project/repo）。"
  value       = module.agent_artifact_registry.repository_url
}

output "cloud_run_region" {
  description = "Cloud Run のリージョン（デプロイ Workflow 用）。"
  value       = var.region
}

output "cloud_run_service_name" {
  description = "Cloud Run サービス名。"
  value       = module.agent_cloud_run.service_name
}

output "cloud_run_url" {
  description = "Cloud Run サービスの URL。"
  value       = module.agent_cloud_run.service_uri
}
