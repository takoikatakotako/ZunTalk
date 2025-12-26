module "ecr" {
  source = "../../modules/ecr"

  repository_name      = "zuntalk-backend"
  image_tag_mutability = "MUTABLE"
  scan_on_push         = false
  max_image_count      = 20
  allowed_account_ids  = ["039612872248", "986921280333"] # Development, Production account

  tags = {
    Name = "zuntalk-backend"
  }
}
