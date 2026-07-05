terraform {
  backend "gcs" {
    bucket = "takoikatakotako-tfstate-bucket"
    prefix = "zuntalk-agent/dev"
  }
}
