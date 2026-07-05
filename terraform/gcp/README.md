# terraform/gcp — ずんだもんエージェントの GCP 基盤

`agent/`（Go + Vertex AI）を Cloud Run にデプロイするための Terraform。
既存 sandbox プロジェクト（`sandbox-492513`）に相乗りし、dev/prod で
Artifact Registry / Cloud Run / Secret Manager / 実行SA を分離する。

プロジェクト本体は `gcp-iac` リポジトリが管理している。ここでは `google_project` を作らず、
中のリソースだけを追加する。

## 構成

| パス | 役割 |
|---|---|
| `modules/project-service` | GCP API 有効化 |
| `modules/service-account` | Service Account |
| `modules/artifact-registry` | Artifact Registry repository |
| `modules/secret-manager-secret` | Secret Manager secret と accessor |
| `modules/cloud-run` | Cloud Run service と invoker IAM |
| `environments/dev` | dev 環境。state prefix は `zuntalk-agent/dev` |
| `environments/prod` | prod 環境。state prefix は `zuntalk-agent/prod` |

環境ごとの主なリソース名:

| 環境 | Cloud Run / Artifact Registry | Secret Manager |
|---|---|---|
| dev | `zuntalk-agent-dev` | `zuntalk-agent-dev-api-key` |
| prod | `zuntalk-agent-prod` | `zuntalk-agent-prod-api-key` |

アクセス制御は Cloud Run を public にしつつ、Go 側の `X-Api-Key` 検証で保護する。

## bootstrap

```bash
# 1. 認証
gcloud auth login
gcloud auth application-default login

# 2. dev の初回 apply
cd terraform/gcp/environments/dev
terraform init
terraform apply

# 3. dev API キーの値を投入
printf '%s' "$(openssl rand -hex 32)" | \
  gcloud secrets versions add zuntalk-agent-dev-api-key --data-file=- --project=sandbox-492513

# 4. prod の初回 apply
cd ../prod
terraform init
terraform apply

# 5. prod API キーの値を投入
printf '%s' "$(openssl rand -hex 32)" | \
  gcloud secrets versions add zuntalk-agent-prod-api-key --data-file=- --project=sandbox-492513
```

その後 `agent/**` を main に push すると dev にデプロイする。prod は
`.github/workflows/agent-deploy.yml` を手動実行して `environment=prod` を選択する。

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
