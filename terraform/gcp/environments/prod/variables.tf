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

variable "agent_daily_limit" {
  description = "deviceId ごとの /agent 日次呼び出し上限。0以下で無制限。"
  type        = number
  default     = 50
}

variable "apns_key_id" {
  description = "APNs Auth Key (.p8) の Key ID。Apple Developer > Keys で作成したもの。"
  type        = string
  default     = ""
}

variable "apns_team_id" {
  description = "Apple Developer の Team ID。"
  type        = string
  default     = "5RH346BQ66"
}

variable "image" {
  description = "Cloud Run の初期イメージ。実イメージは CI(agent-deploy.yml)が更新し、TF は ignore_changes で無視する。"
  type        = string
  default     = "us-docker.pkg.dev/cloudrun/container/hello"
}
