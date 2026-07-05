# ZunTalk Agent

ずんだもんの「エージェントモード」用バックエンド。ユーザーの発話に対し、

1. **planner**（Gemini）が必要なツール（Gmail / Calendar）を計画
2. **端末(iOS)** がその計画を Keychain のトークンで実行（Gmail/Calendar API は端末から直接叩く）
3. **responder**（Gemini）が結果を踏まえてずんだもん口調で応答

を行う、AI オーケストレーション専任のサーバー（Go + Echo + Vertex AI）。

> **セキュリティ方針**: ユーザーの Google アクセストークンはサーバーに一切保存しない。
> サーバーが持つ秘密は自分の GCP/Vertex 権限のみ。

## 構成

```
main.go                エントリーポイント（Echo / ルーティング）
config/                環境変数の読み込み
model/                 リクエスト・レスポンスの型
llm/                   Vertex AI(Gemini) クライアントの薄いラッパ
handler/               HTTP ハンドラ
orchestrator/          planner / responder（司令塔）
```

## API

### `POST /agent`

ステートレス。端末が会話を駆動する。

**1巡目（計画）**
```jsonc
// リクエスト
{ "message": "予定とメールを確認して" }
// レスポンス
{ "type": "tool_calls",
  "plan": [
    { "capability": "calendar", "query": "今日と明日の予定" },
    { "capability": "gmail",    "query": "最近の重要なメール" }
  ] }
```

**2巡目（応答）** — 端末がツールを実行した結果を添えて再送
```jsonc
// リクエスト
{ "message": "予定とメールを確認して",
  "results": [
    { "capability": "calendar", "content": "14:00 歯医者 / 18:00 MTG" },
    { "capability": "gmail",    "content": "請求書の確認依頼が1件" }
  ] }
// レスポンス
{ "type": "final", "reply": "今日は14時に歯医者なのだ！…" }
```

雑談（ツール不要）の場合は1巡目で即 `type: "final"` が返る。

### `GET /health`
`{ "status": "ok" }`

## ローカル実行

Vertex AI を呼ぶため Google Cloud の認証情報（ADC）が必要。

```bash
# 1. ADC でログイン（Vertex 呼び出し用のキーレス認証）
gcloud auth application-default login

# 2. 環境変数
cp .env.example .env   # GCP_PROJECT_ID を自分のプロジェクトに設定

# 3. 起動
go run .

# 4. 動作確認
curl -XPOST localhost:8080/agent \
  -H 'Content-Type: application/json' \
  -d '{"message":"予定とメールを確認して"}'
```

事前に対象プロジェクトで Vertex AI API を有効化しておくこと
（`gcloud services enable aiplatform.googleapis.com`）。

## ビルド

```bash
go build ./...     # ビルド（GCP認証なしでも通る）
go vet ./...
docker build -t zuntalk-agent .
```

## 電話予約（VoIP push）

指定時刻にずんだもんから電話がかかってくる機能のサーバー側。
Firestore に予約を保存し、Cloud Scheduler（毎分）→ `/internal/dispatch` → APNs（VoIP push）→
iOS の PushKit/CallKit で着信、という流れ。

### エンドポイント

| メソッド | パス | 認証 | 説明 |
|---------|------|------|------|
| PUT | `/devices` | X-Api-Key | VoIP トークンの登録（冪等） |
| POST | `/calls` | X-Api-Key | 電話の予約作成 `{deviceId, scheduledAt(RFC3339)}` |
| GET | `/calls?deviceId=` | X-Api-Key | 予約一覧 |
| DELETE | `/calls/:id?deviceId=` | X-Api-Key | 予約キャンセル |
| POST | `/internal/dispatch` | Scheduler OIDC | 期限到来分に VoIP push を送信 |

### Firestore

- `devices/{deviceId}`: voipToken / apnsEnv / bundleId / invalidatedAt
- `scheduledCalls/{id}`: deviceId / scheduledAt(UTC) / status（scheduled→sending→sent|failed、canceled/missed）
- 複合インデックス `(status ASC, scheduledAt ASC)` が必要（Terraform で定義済み）
- **注意**: Firestore の `(default)` DB はプロジェクトに1つ。dev/prod は同じ DB・コレクションを共有する

### 手動 push テスト（サーバー不要）

実機で VoIP トークンを Xcode コンソールから拾い、直接 APNs に送る:

```bash
go run ./cmd/apns-push \
  -p8 ~/Downloads/AuthKey_XXXXXXXXXX.p8 \
  -key-id XXXXXXXXXX \
  -token <VoIPトークン(hex)> \
  -env sandbox \
  -topic com.swiswiswift.zuntalk.dev.voip
```

アプリを kill・ロックした状態でもネイティブ着信 UI が出れば成功。

### APNs キーの設定（Cloud Run）

```bash
# .p8 を Secret Manager に投入（Terraform が secret を作成した後）
gcloud secrets versions add zuntalk-agent-dev-apns-key \
  --data-file=AuthKey_XXXXXXXXXX.p8 --project sandbox-492513
```

`APNS_KEY_ID` は tfvar（`apns_key_id`）で注入する。
Secret にバージョンが無い状態で Cloud Run に `APNS_AUTH_KEY` を参照させると
リビジョンが起動に失敗するため、**先に .p8 を投入してから** terraform apply / デプロイすること。
