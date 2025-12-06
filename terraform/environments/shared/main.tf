module "ecr" {
  source = "../../modules/ecr"

  repository_name      = "zuntalk-backend"
  image_tag_mutability = "MUTABLE"
  scan_on_push         = true
  max_image_count      = 10

  tags = {
    Name = "zuntalk-backend"
  }
}
