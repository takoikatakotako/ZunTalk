locals {
  environment       = "dev"
  agent_name        = "zuntalk-agent-${local.environment}"
  api_key_secret_id = "${local.agent_name}-api-key"
  required_services = [
    "run.googleapis.com",
    "aiplatform.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "iamcredentials.googleapis.com",
  ]
}

# =============================================================================
# Project Services
# =============================================================================

module "project_services" {
  source = "../../modules/project-service"

  project_id         = var.project_id
  services           = local.required_services
  disable_on_destroy = false
}

# =============================================================================
# Service Accounts
# =============================================================================

module "agent_runtime_service_account" {
  source = "../../modules/service-account"

  project_id   = var.project_id
  account_id   = "agent-runtime-${local.environment}"
  display_name = "ZunTalk Agent ${local.environment} Cloud Run runtime"

  depends_on = [module.project_services]
}

resource "google_project_iam_member" "agent_runtime_vertex" {
  project = var.project_id
  role    = "roles/aiplatform.user"
  member  = "serviceAccount:${module.agent_runtime_service_account.email}"
}

# =============================================================================
# Artifact Registry
# =============================================================================

module "agent_artifact_registry" {
  source = "../../modules/artifact-registry"

  project_id    = var.project_id
  location      = var.region
  repository_id = local.agent_name
  description   = "ZunTalk ${local.environment} ずんだもんエージェントのコンテナイメージ"

  depends_on = [module.project_services]
}

# =============================================================================
# Secret Manager
# =============================================================================

module "agent_api_key" {
  source = "../../modules/secret-manager-secret"

  project_id           = var.project_id
  secret_id            = local.api_key_secret_id
  replication_location = var.region
  accessor_members = [
    "serviceAccount:${module.agent_runtime_service_account.email}",
  ]

  depends_on = [module.project_services]
}

# =============================================================================
# Cloud Run
# =============================================================================

module "agent_cloud_run" {
  source = "../../modules/cloud-run"

  project_id            = var.project_id
  service_name          = local.agent_name
  location              = var.region
  service_account_email = module.agent_runtime_service_account.email
  image                 = var.image

  environment_variables = {
    APP_ENV         = local.environment
    GCP_PROJECT_ID  = var.project_id
    VERTEX_LOCATION = var.vertex_location
    GEMINI_MODEL    = var.gemini_model
  }

  secret_environment_variables = {
    AGENT_API_KEY = {
      secret_id = module.agent_api_key.secret_id
      version   = "latest"
    }
  }

  invoker_members = ["allUsers"]

  depends_on = [
    module.project_services,
    module.agent_api_key,
    google_project_iam_member.agent_runtime_vertex,
  ]
}
