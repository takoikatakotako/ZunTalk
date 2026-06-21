terraform {
  # state は gcp-iac が sandbox に用意した共有バケットを prefix で間借りする。
  backend "gcs" {
    bucket = "takoikatakotako-tfstate-bucket"
    prefix = "zuntalk-agent"
  }
}
