# GitHub Actions(ZunTalk リポジトリ)から Cloud Run にデプロイするための
# Workload Identity Federation とデプロイ用サービスアカウント。
# gcp-iac の analytics/github_actions.tf を踏襲。
#
# 初回 apply は所有者がローカルで実行する（WIF が無いと CI が認証できないため）。

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "zuntalk-github-actions"
  display_name              = "ZunTalk GitHub Actions"
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.repository" = "assertion.repository"
  }

  # 指定リポジトリからのトークンのみ受け付ける。
  attribute_condition = "assertion.repository == \"${var.github_repo}\""

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

# デプロイ用サービスアカウント。
resource "google_service_account" "deployer" {
  project      = var.project_id
  account_id   = "github-actions-agent"
  display_name = "GitHub Actions agent deploy (ZunTalk)"
}

# Cloud Run のデプロイ権限。
resource "google_project_iam_member" "deployer_run" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.deployer.email}"
}

# Artifact Registry へのイメージ push 権限。
resource "google_project_iam_member" "deployer_ar" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.deployer.email}"
}

# 実行SAとしてデプロイするための actAs 権限。
resource "google_service_account_iam_member" "deployer_actas_runtime" {
  service_account_id = google_service_account.runtime.name
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${google_service_account.deployer.email}"
}

# 指定リポジトリからの principalSet がデプロイSAを借用できるようにする。
resource "google_service_account_iam_member" "deployer_wif" {
  service_account_id = google_service_account.deployer.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repo}"
}
