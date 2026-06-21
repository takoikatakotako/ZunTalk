terraform {
  # state は sandbox プロジェクト内の専用バケット（bootstrap で作成）。
  # gcp-iac の tfstate バケットとは分離し、ZunTalk 側で自己完結させる。
  backend "gcs" {
    bucket = "zuntalk-agent-tfstate"
    prefix = "agent"
  }
}
