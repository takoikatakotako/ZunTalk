# API仕様

## ベースURL

### Dev環境
```
https://7tvpxuwt4qxqqp5hruodvxtb3i0biwpo.lambda-url.ap-northeast-1.on.aws
```

### Prod環境
```
https://d53er5cb4n63l2dbbkaqjqesde0lfgpb.lambda-url.ap-northeast-1.on.aws
```

## エンドポイント一覧

### POST /api/chat

AI会話を生成します。

**リクエスト:**
```json
{
  "messages": [
    {
      "role": "system",
      "content": "あなたはずんだもんです..."
    },
    {
      "role": "user",
      "content": "こんにちは！"
    }
  ],
  "model": "gpt-4o-mini",
  "maxTokens": 500
}
```

**パラメータ:**

| フィールド | 型 | 必須 | 説明 |
|----------|---|-----|------|
| messages | Message[] | ✅ | 会話履歴 |
| model | string | ✅ | OpenAIモデル（gpt-4o-mini/gpt-4o） |
| maxTokens | int | ❌ | 最大トークン数（デフォルト: 500） |

**Message:**

| フィールド | 型 | 必須 | 説明 |
|----------|---|-----|------|
| role | string | ✅ | ロール（system/user/assistant） |
| content | string | ✅ | メッセージ内容 |

**レスポンス:**
```json
{
  "message": {
    "role": "assistant",
    "content": "こんにちはなのだ！今日はどんなお話をするのだ？"
  },
  "usage": {
    "promptTokens": 45,
    "completionTokens": 23,
    "totalTokens": 68
  }
}
```

**エラー:**
```json
{
  "error": "Invalid request format"
}
```

### GET /api/info

アプリケーション情報を取得します。

**リクエスト:**
```
GET /api/info
```

**レスポンス:**
```json
{
  "maintenance": false,
  "minimumVersion": "1.0.0",
  "message": null
}
```

**フィールド:**

| フィールド | 型 | 説明 |
|----------|---|------|
| maintenance | boolean | メンテナンスモード（true: メンテナンス中） |
| minimumVersion | string | 最小対応バージョン |
| message | string? | メッセージ（メンテナンス時など） |

### GET /health

ヘルスチェック用エンドポイント。

**リクエスト:**
```
GET /health
```

**レスポンス:**
```json
{
  "status": "ok"
}
```

### GET /api/error

エラーテスト用エンドポイント（Slack通知確認用）。

**リクエスト:**
```
GET /api/error
```

**レスポンス:**
```json
{
  "error": "Test error for Slack notification"
}
```

## 認証

現在のバージョンでは認証は不要です。

!!! warning "セキュリティ"
    将来的には API Key 認証を実装予定です。

## レート制限

Lambda の同時実行数制限により、自動的にレート制限されます。

## エラーコード

| HTTPステータス | 説明 |
|---------------|------|
| 200 | 成功 |
| 400 | リクエストエラー（パラメータ不正など） |
| 500 | サーバーエラー（OpenAI API エラーなど） |

## 使用例

### curl

```bash
# AI会話
curl -X POST https://7tvpxuwt4qxqqp5hruodvxtb3i0biwpo.lambda-url.ap-northeast-1.on.aws/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "system", "content": "あなたはずんだもんです"},
      {"role": "user", "content": "こんにちは"}
    ],
    "model": "gpt-4o-mini",
    "maxTokens": 500
  }'

# アプリ情報取得
curl https://7tvpxuwt4qxqqp5hruodvxtb3i0biwpo.lambda-url.ap-northeast-1.on.aws/api/info

# ヘルスチェック
curl https://7tvpxuwt4qxqqp5hruodvxtb3i0biwpo.lambda-url.ap-northeast-1.on.aws/health
```

### Swift (iOS)

```swift
struct ChatRequest: Codable {
    let messages: [Message]
    let model: String
    let maxTokens: Int
}

struct Message: Codable {
    let role: String
    let content: String
}

// API呼び出し
let request = ChatRequest(
    messages: [
        Message(role: "system", content: "あなたはずんだもんです"),
        Message(role: "user", content: "こんにちは")
    ],
    model: "gpt-4o-mini",
    maxTokens: 500
)

let url = URL(string: APIConfig.chatEndpoint)!
var urlRequest = URLRequest(url: url)
urlRequest.httpMethod = "POST"
urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
urlRequest.httpBody = try JSONEncoder().encode(request)

let (data, _) = try await URLSession.shared.data(for: urlRequest)
let response = try JSONDecoder().decode(ChatResponse.self, from: data)
```

## OpenAPI仕様書

完全なAPI仕様は [OpenAPI仕様書](https://github.com/takoikatakotako/ZunTalk/blob/main/docs/api/openapi.yaml) をご覧ください。
