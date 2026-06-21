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
