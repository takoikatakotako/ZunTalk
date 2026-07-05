variable "project_id" {
  description = "デプロイ先 GCP プロジェクト ID。"
  type        = string
  default     = "sandbox-492513"
}

variable "region" {
  description = "Cloud Run / Artifact Registry のリージョン。"
  type        = string
  default     = "asia-northeast1"
}

variable "vertex_location" {
  description = "Vertex AI(Gemini) のロケーション。"
  type        = string
  default     = "us-central1"
}

variable "gemini_model" {
  description = "使用する Gemini モデル名。"
  type        = string
  default     = "gemini-2.5-flash"
}

variable "image" {
  description = "Cloud Run の初期イメージ。実イメージは CI(agent-deploy.yml)が更新し、TF は ignore_changes で無視する。"
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}
