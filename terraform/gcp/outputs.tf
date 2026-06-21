output "cloud_run_url" {
  description = "Cloud Run サービスの URL。"
  value       = google_cloud_run_v2_service.agent.uri
}

output "artifact_registry_repo" {
  description = "イメージを push する Artifact Registry リポジトリ（host/project/repo）。"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.agent.repository_id}"
}

output "wif_provider" {
  description = "agent-deploy.yml に直書きする WIF プロバイダのリソース名。"
  value       = google_iam_workload_identity_pool_provider.github.name
}

output "deploy_service_account_email" {
  description = "agent-deploy.yml に直書きするデプロイSAのメール。"
  value       = google_service_account.deployer.email
}

output "cloud_run_region" {
  description = "Cloud Run のリージョン（デプロイ Workflow 用）。"
  value       = var.region
}
