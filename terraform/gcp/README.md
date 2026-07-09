# terraform/gcp — ずんだもんエージェントの GCP 基盤

`agent/`（Go + Vertex AI）を Cloud Run にデプロイするための Terraform。
既存 sandbox プロジェクト（`sandbox-492513`）に相乗りし、dev/prod で
Artifact Registry / Cloud Run / Secret Manager / 実行SA / Firestore データベース /
Cloud Scheduler を分離する。Firestore は dev が `(default)`、prod が名前付きDB
`zuntalk-prod` を使い、データを完全分離する（将来 prod を別プロジェクト・
別アカウントへ移してもコード変更なしで追従できる）。

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
| `modules/cloud-scheduler-job` | Cloud Scheduler ジョブ（電話予約ディスパッチ） |
| `environments/dev` | dev 環境。state prefix は `zuntalk-agent/dev` |
| `environments/prod` | prod 環境。state prefix は `zuntalk-agent/prod` |

環境ごとの主なリソース名:

| 環境 | Cloud Run / Artifact Registry | Secret Manager | Firestore DB |
|---|---|---|---|
| dev | `zuntalk-agent-dev` | `zuntalk-agent-dev-api-key` / `zuntalk-agent-dev-apns-key` | `(default)` |
| prod | `zuntalk-agent-prod` | `zuntalk-agent-prod-api-key` / `zuntalk-agent-prod-apns-key` | `zuntalk-prod` |

接続先の Firestore DB は Cloud Run の環境変数 `FIRESTORE_DATABASE` で切り替える
（未設定なら `(default)`）。

アクセス制御は Cloud Run を public にしつつ、Go 側の `X-Api-Key` 検証で保護する。
**API キーは dev/prod で別の値**にする（独立してローテーションできるように）。
iOS 側は `Secrets.xcconfig` に `AGENT_API_KEY_DEV` / `AGENT_API_KEY_PROD` を持ち、
Development/Production スキームがそれぞれ対応する値を送る。

## bootstrap

```bash
# 1. 認証
gcloud auth login
gcloud auth application-default login

# 2. dev の初回 apply
cd terraform/gcp/environments/dev
terraform init
terraform apply

# 3. dev API キーの値を投入（dev/prod で別の値にすること）
printf '%s' "$(openssl rand -hex 32)" | \
  gcloud secrets versions add zuntalk-agent-dev-api-key --data-file=- --project=sandbox-492513

# 4. APNs Auth Key (.p8) を dev secret に投入（電話予約の VoIP push 用）
#    未投入のまま Cloud Run をデプロイすると起動に失敗する
gcloud secrets versions add zuntalk-agent-dev-apns-key \
  --data-file=AuthKey_XXXX.p8 --project=sandbox-492513

# 5. prod の初回 apply
cd ../prod
terraform init
terraform apply   # 名前付きDB zuntalk-prod の作成にインデックス構築で数分かかる

# 6. prod API キー（dev とは別値）と APNs Auth Key を投入
printf '%s' "$(openssl rand -hex 32)" | \
  gcloud secrets versions add zuntalk-agent-prod-api-key --data-file=- --project=sandbox-492513
gcloud secrets versions add zuntalk-agent-prod-apns-key \
  --data-file=AuthKey_XXXX.p8 --project=sandbox-492513   # .p8 は dev と同一チームキーでよい
```

`.p8` は環境非依存で、同じキーで sandbox / production の APNs 両方に送れる。
投入した API キーは iOS の `Secrets.xcconfig`（`AGENT_API_KEY_DEV` / `AGENT_API_KEY_PROD`）
にも設定する。

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
  -d '{"message":"今日の予定を教えて","capabilities":["calendar"],"deviceId":"test"}'
```
