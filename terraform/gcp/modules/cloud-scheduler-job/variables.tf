variable "project_id" {
  description = "GCP プロジェクト ID。"
  type        = string
}

variable "region" {
  description = "Cloud Scheduler のリージョン。"
  type        = string
}

variable "name" {
  description = "ジョブ名。"
  type        = string
}

variable "description" {
  description = "ジョブの説明。"
  type        = string
  default     = ""
}

variable "schedule" {
  description = "cron 形式のスケジュール（例: \"* * * * *\"）。"
  type        = string
}

variable "time_zone" {
  description = "スケジュールのタイムゾーン。"
  type        = string
  default     = "Etc/UTC"
}

variable "attempt_deadline" {
  description = "HTTP ターゲットの実行タイムアウト。"
  type        = string
  default     = "60s"
}

variable "http_method" {
  description = "HTTP メソッド。"
  type        = string
  default     = "POST"
}

variable "uri" {
  description = "呼び出し先 URI。"
  type        = string
}

variable "service_account_email" {
  description = "OIDC トークンを発行するサービスアカウントの email。"
  type        = string
}

variable "audience" {
  description = "OIDC トークンの audience。呼び出し先がこの値を検証する。"
  type        = string
}
