module "ecr" {
  source = "../../modules/ecr"

  repository_name      = "zuntalk-backend"
  image_tag_mutability = "MUTABLE"
  scan_on_push         = false
  max_image_count      = 20

  tags = {
    Name = "zuntalk-backend"
  }
}
