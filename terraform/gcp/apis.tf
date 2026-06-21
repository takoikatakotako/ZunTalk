# このコンポジションが必要とする API を有効化する。
# sandbox プロジェクトは gcp-iac と共有だが、gcp-iac 側はサービスを管理していないため衝突しない。
# disable_on_destroy=false: 共有プロジェクトなので destroy 時に API を無効化しない。

locals {
  services = [
    "run.googleapis.com",
    "aiplatform.googleapis.com",
    "artifactregistry.googleapis.com",
    "secretmanager.googleapis.com",
    "iamcredentials.googleapis.com",
  ]
}

resource "google_project_service" "services" {
  for_each = toset(local.services)

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}
