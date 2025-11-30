# ZunTalk Backend

ZunTalkのバックエンドAPI（Go + Echo）

## 機能

- OpenAI Chat Completions APIのプロキシ
- シンプルなRESTful API
- Docker & AWS Lambda対応

## 必要要件

- Go 1.21以上
- OpenAI APIキー
- (オプション) Docker

## ディレクトリ構成

```
backend/
├── main.go              # エントリーポイント
├── handler/             # HTTPハンドラー
│   └── chat.go
├── service/             # ビジネスロジック
│   └── openai.go
├── model/               # データモデル
│   └── chat.go
├── config/              # 設定管理
│   └── config.go
├── Dockerfile           # AWS Lambda用（Lambda Web Adapter使用）
├── .env.example
├── go.mod
└── README.md
```

## セットアップ

### 1. 依存関係のインストール

```bash
go mod download
```

### 2. 環境変数の設定

`.env.example`をコピーして`.env`を作成：

```bash
cp .env.example .env
```

`.env`ファイルを編集：

```
OPENAI_API_KEY=sk-proj-your_api_key_here
PORT=8080
```

### 3. ローカルで起動

```bash
# 環境変数を読み込んで起動
export $(cat .env | xargs) && go run main.go
```

サーバーは `http://localhost:8080` で起動します。

## Docker

### ローカルテスト用

```bash
docker build -t zuntalk-backend .
docker run -p 8080:8080 -e OPENAI_API_KEY=your_key zuntalk-backend
```

## AWS Lambdaデプロイ

このアプリケーションはAWS Lambda Web Adapterを使用してLambdaで動作します。

### 1. ECRにプッシュ

```bash
# ECRリポジトリを作成
aws ecr create-repository --repository-name zuntalk-backend

# ログイン
aws ecr get-login-password --region ap-northeast-1 | \
  docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-northeast-1.amazonaws.com

# ビルド & タグ付け
docker build -t <account-id>.dkr.ecr.ap-northeast-1.amazonaws.com/zuntalk-backend:latest .

# プッシュ
docker push <account-id>.dkr.ecr.ap-northeast-1.amazonaws.com/zuntalk-backend:latest
```

### 2. Lambda関数を作成

- コンテナイメージからLambda関数を作成
- 環境変数 `OPENAI_API_KEY` を設定
- メモリ: 512MB以上推奨
- タイムアウト: 30秒以上推奨

### 3. API Gatewayと連携

Lambda関数にAPI Gatewayをトリガーとして追加

## API仕様

詳細なAPI仕様は `/docs/api/openapi.yaml` を参照してください。

### エンドポイント

#### POST /api/chat

AI会話を生成します。

**リクエスト例:**

```bash
curl -X POST http://localhost:8080/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {
        "role": "user",
        "content": "こんにちは！"
      }
    ],
    "model": "gpt-4o-mini"
  }'
```

**レスポンス例:**

```json
{
  "message": {
    "role": "assistant",
    "content": "こんにちは！何かお手伝いできることはありますか？"
  },
  "tokensUsed": 150
}
```

#### GET /health

ヘルスチェック用のエンドポイント。

```bash
curl http://localhost:8080/health
```

**レスポンス:**

```json
{
  "status": "ok"
}
```

## 開発

### ビルド

```bash
go build -o bin/api main.go
```

### 実行

```bash
export $(cat .env | xargs) && ./bin/api
```

## 本番環境

環境変数 `OPENAI_API_KEY` と `PORT` を設定してください。

```bash
OPENAI_API_KEY=your_key PORT=8080 ./bin/api
```
