locals {
  environment        = "dev"
  agent_name         = "zuntalk-agent-${local.environment}"
  api_key_secret_id  = "${local.agent_name}-api-key"
  apns_key_secret_id = "${local.agent_name}-apns-key"
  # Scheduler の OIDC トークンと dispatch エンドポイントの照合に使う audience。
  # Cloud Run の URL に依存させると自己参照になるため固定文字列にする。
  dispatch_audience = "${local.agent_name}-dispatch"
  required_services = [
    "run.googleapis.com",
    "aiplatform.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "iamcredentials.googleapis.com",
    "firestore.googleapis.com",
    "cloudscheduler.googleapis.com",
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

# 電話予約・端末トークンを Firestore に保存するため
resource "google_project_iam_member" "agent_runtime_datastore" {
  project = var.project_id
  role    = "roles/datastore.user"
  member  = "serviceAccount:${module.agent_runtime_service_account.email}"
}

# /internal/dispatch を毎分叩く Cloud Scheduler ジョブ用 SA
module "call_dispatcher_service_account" {
  source = "../../modules/service-account"

  project_id   = var.project_id
  account_id   = "call-dispatcher-${local.environment}"
  display_name = "ZunTalk ${local.environment} 電話予約ディスパッチャ (Cloud Scheduler)"

  depends_on = [module.project_services]
}

# =============================================================================
# Firestore
# =============================================================================
# 注意: Firestore の (default) データベースはプロジェクトに1つのみ。
# dev/prod は同じ sandbox プロジェクトを使うため、DB とインデックスは
# dev 側でのみ定義し、prod は同じ DB（コレクションも共有）を参照する。

resource "google_firestore_database" "default" {
  project     = var.project_id
  name        = "(default)"
  location_id = var.region
  type        = "FIRESTORE_NATIVE"

  delete_protection_state = "DELETE_PROTECTION_ENABLED"
  deletion_policy         = "ABANDON"

  depends_on = [module.project_services]
}

# ディスパッチャの期限到来クエリ（status == && scheduledAt 範囲）用の複合インデックス
resource "google_firestore_index" "scheduled_calls_status_scheduled_at" {
  project    = var.project_id
  database   = google_firestore_database.default.name
  collection = "scheduledCalls"

  fields {
    field_path = "status"
    order      = "ASCENDING"
  }

  fields {
    field_path = "scheduledAt"
    order      = "ASCENDING"
  }
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

# APNs Auth Key (.p8) の中身。値は手動で投入する（TF には書かない）:
#   gcloud secrets versions add zuntalk-agent-dev-apns-key --data-file=AuthKey_XXXX.p8 --project sandbox-492513
# バージョン未投入のまま Cloud Run をデプロイすると起動に失敗するので注意。
module "agent_apns_key" {
  source = "../../modules/secret-manager-secret"

  project_id           = var.project_id
  secret_id            = local.apns_key_secret_id
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

    APNS_KEY_ID               = var.apns_key_id
    APNS_TEAM_ID              = var.apns_team_id
    SCHEDULER_SERVICE_ACCOUNT = module.call_dispatcher_service_account.email
    DISPATCH_AUDIENCE         = local.dispatch_audience
  }

  secret_environment_variables = {
    AGENT_API_KEY = {
      secret_id = module.agent_api_key.secret_id
      version   = "latest"
    }
    APNS_AUTH_KEY = {
      secret_id = module.agent_apns_key.secret_id
      version   = "latest"
    }
  }

  invoker_members = ["allUsers"]

  depends_on = [
    module.project_services,
    module.agent_api_key,
    module.agent_apns_key,
    google_project_iam_member.agent_runtime_vertex,
    google_project_iam_member.agent_runtime_datastore,
  ]
}

# =============================================================================
# Cloud Scheduler
# =============================================================================

# 毎分 /internal/dispatch を叩き、期限が到来した電話予約に VoIP push を送らせる。
module "call_dispatch_scheduler" {
  source = "../../modules/cloud-scheduler-job"

  project_id  = var.project_id
  region      = var.region
  name        = "${local.agent_name}-call-dispatch"
  description = "期限到来した電話予約の VoIP push 送信（毎分・60秒先読みで秒精度発火）"
  schedule    = "* * * * *"
  # dispatch は次の60秒以内の予約を発火時刻まで待ってから送るため、1分より長めに取る
  attempt_deadline = "90s"

  uri                   = "${module.agent_cloud_run.service_uri}/internal/dispatch"
  service_account_email = module.call_dispatcher_service_account.email
  audience              = local.dispatch_audience

  depends_on = [module.project_services]
}
