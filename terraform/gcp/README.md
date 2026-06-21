# terraform/gcp — ずんだもんエージェントの GCP 基盤

`agent/`（Go + Vertex AI）を **Cloud Run** にデプロイするための Terraform。
既存 **sandbox プロジェクト（`sandbox-492513`）に相乗り**し、その中に
Artifact Registry / Cloud Run / Secret Manager / 実行SA / WIF を追加する。

> プロジェクト本体は `gcp-iac` リポジトリが管理している。ここでは **`google_project` を作らず**、
> 中のリソースだけを追加する（state 衝突回避）。

## 構成（gcp-iac 踏襲）

| ファイル | 役割 |
|---|---|
| `versions.tf` | google provider `~> 6.0` / provider 設定 |
| `terraform.tf` | GCS backend（bucket=`zuntalk-agent-tfstate`, prefix=`agent`） |
| `variables.tf` | project_id / region / vertex_location / gemini_model / github_repo / image |
| `apis.tf` | run / aiplatform / artifactregistry / secretmanager / iamcredentials を有効化 |
| `artifact_registry.tf` | コンテナイメージ用 Docker リポジトリ |
| `secrets.tf` | `agent-api-key`（箱のみ。値は out-of-band 投入）＋ 実行SAへの accessor |
| `cloud_run.tf` | 実行SA(+Vertex権限) と Cloud Run サービス（public invoker、image は ignore_changes） |
| `github_actions.tf` | WIF プール/プロバイダ ＋ デプロイSA（run.admin / artifactregistry.writer / actAs） |
| `outputs.tf` | cloud_run_url / artifact_registry_repo / wif_provider / deploy_service_account_email |

アクセス制御は Cloud Run を public にしつつ、Go 側の `X-Api-Key` 検証で保護する。

## bootstrap（所有者がローカルで一度きり）

```bash
# 1. 認証
gcloud auth login
gcloud auth application-default login

# 2. state バケットを作成（sandbox プロジェクト内）
gcloud storage buckets create gs://zuntalk-agent-tfstate \
  --project=sandbox-492513 --location=asia-northeast1 --uniform-bucket-level-access

# 3. 初回 apply（WIF/SA/AR/CloudRun/Secret を作成。Cloud Run は placeholder イメージで起動）
cd terraform/gcp
terraform init
terraform apply

# 4. APIキーの値を投入（生成して Secret に追加）
printf '%s' "$(openssl rand -hex 32)" | \
  gcloud secrets versions add agent-api-key --data-file=- --project=sandbox-492513

# 5. terraform output を確認し、.github/workflows/agent-deploy.yml の
#    workload_identity_provider の PROJECT_NUMBER を埋める
terraform output wif_provider
terraform output deploy_service_account_email
```

その後 `agent/**` を main に push（または Actions を手動 dispatch）すると、
`agent-deploy.yml` が実イメージを build → push → Cloud Run へデプロイする。

## 動作確認

```bash
RUN_URL=$(terraform output -raw cloud_run_url)
# /health は鍵不要
curl "$RUN_URL/health"
# /agent は X-Api-Key 必須
curl -H "X-Api-Key: <投入した鍵>" -XPOST "$RUN_URL/agent" \
  -H 'Content-Type: application/json' \
  -d '{"message":"予定とメールを確認して"}'
```
