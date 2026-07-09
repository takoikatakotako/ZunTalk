# ZunTalk Agent

ずんだもんの「エージェントモード」用バックエンド。ユーザーの発話に対し、

1. **planner**（Gemini）が必要なツール（カレンダー）を計画
2. **端末(iOS)** がその計画を実行（カレンダーは EventKit で端末内から読む）
3. **responder**（Gemini）が結果を踏まえてずんだもん口調で応答

を行う、AI オーケストレーション専任のサーバー（Go + Echo + Vertex AI）。

> **セキュリティ方針**: ユーザーの個人データ（カレンダー等）はサーバーに保存しない。
> ツールは端末内で実行し、AI 応答生成に必要な結果テキストだけをサーバーに渡す。
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
{
  "message": "今日の予定を教えて",
  "capabilities": ["calendar"],
  "deviceId": "device-uuid"
}
// レスポンス
{ "type": "tool_calls",
  "plan": [
    { "capability": "calendar", "query": "今日と明日の予定" }
  ] }
```

**2巡目（応答）** — 端末がツールを実行した結果を添えて再送
```jsonc
// リクエスト
{ "message": "今日の予定を教えて",
  "results": [
    { "capability": "calendar", "content": "14:00 歯医者 / 18:00 MTG" }
  ] }
// レスポンス
{ "type": "final", "reply": "今日は14時に歯医者なのだ！…" }
```

`capabilities` は端末が実行できるツールの申告。現状は `calendar`（EventKit）のみ。
未指定の場合は後方互換として全ツール（= `calendar`）を利用可能とみなす。
`deviceId` は日次利用回数制限に使う。

雑談（ツール不要）の場合は1巡目で即 `type: "final"` が返る。

### 利用回数制限

`AGENT_DAILY_LIMIT` で deviceId ごとの `/agent` 日次呼び出し上限を設定できる。
デフォルトは `50`。`0` 以下にすると制限しない。
カウントは1巡目（計画フェーズ）のみ。2巡目（ツール実行結果あり）は常に通し、
上限の境界で会話が途中で打ち切られないようにしている。
上限超過は 429 `RATE_LIMITED` を返す。

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
  -d '{"message":"今日の予定を教えて"}'
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
- `agentUsage/{yyyy-mm-dd}_{deviceId}`: /agent の日次呼び出し回数（expireAt の TTL で7日後に自動削除）
- 複合インデックス `(status ASC, scheduledAt ASC)` が必要（Terraform で定義済み）
- **接続先データベースは `FIRESTORE_DATABASE` で切り替える**（未設定なら `(default)`）。
  dev は `(default)`、prod は専用の名前付きDB `zuntalk-prod` を使い、**データを完全分離**する。
  各環境が自分のDB・インデックス・TTL を Terraform で所有するため、将来 prod を
  別プロジェクト・別アカウントへ移しても追従できる。

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
