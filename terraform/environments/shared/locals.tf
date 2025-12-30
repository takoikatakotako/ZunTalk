locals {
  ecr_allowed_account_ids = [var.development_account_id, var.production_account_id]
}
