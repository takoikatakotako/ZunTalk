variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-1"
}

variable "openai_api_key" {
  description = "OpenAI API key"
  type        = string
  sensitive   = true
}
