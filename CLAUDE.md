# CLAUDE.md - ZunTalk プロジェクトガイド

このドキュメントはClaude Codeがこのリポジトリを理解するためのガイドです。

## プロジェクト概要

**ZunTalk**はずんだもん（キャラクター）とユーザーが音声で会話できるiOSアプリです。

- **AI会話**: OpenAI API（gpt-4o-mini/gpt-4o）で応答生成
- **音声合成**: VOICEVOX Coreでテキストを音声に変換
- **音声認識**: iOS SpeechFrameworkでユーザー音声を認識
- **バックエンド**: AWS Lambda + Go（Echo）でサーバーレス実行

## ディレクトリ構造

```
ZunTalk/
├── ios/                    # iOSアプリ（Swift/SwiftUI）
│   ├── ZunTalk/           # ソースコード
│   │   ├── App/           # エントリーポイント
│   │   ├── Config/        # API設定
│   │   ├── Models/        # データモデル
│   │   ├── Repository/    # データアクセス層
│   │   │   ├── TextGeneration/      # AI会話生成
│   │   │   ├── TextToSpeech/        # 音声合成（VOICEVOX）
│   │   │   ├── SpeechRecognition/   # 音声認識
│   │   │   └── Keychain/            # 認証情報管理
│   │   └── Screens/       # UIビュー
│   ├── Development.xcconfig   # Debug環境設定
│   └── Production.xcconfig    # Release環境設定
├── backend/                # Goバックエンド
│   ├── main.go            # エントリーポイント（Echo設定）
│   ├── handler/           # HTTPハンドラー
│   ├── service/           # ビジネスロジック（OpenAI通信）
│   ├── model/             # データモデル
│   ├── config/            # 環境変数管理
│   └── Dockerfile         # Lambda Web Adapter使用
├── terraform/              # インフラ（IaC）
│   ├── modules/           # 再利用可能モジュール（ecr, lambda）
│   └── environments/      # 環境別設定
│       ├── shared/        # ECR + GitHub Actions IAM
│       ├── dev/           # 開発環境Lambda
│       ├── stg/           # ステージング環境
│       └── prod/          # 本番環境
├── docs/                   # ドキュメント
│   └── api/openapi.yaml   # OpenAPI仕様書
└── .github/workflows/      # CI/CD
    ├── backend-deploy-dev.yml  # Dev環境デプロイ
    ├── backend-deploy-prod.yml # Prod環境デプロイ
    ├── backend-status.yml      # デプロイ状況確認
    └── slack-notifier-build.yml # Slack通知Lambda
```

## 技術スタック

### iOS
- **言語**: Swift
- **UI**: SwiftUI
- **最小iOS**: 17.0
- **音声合成**: VOICEVOX Core（C言語フレームワーク）
- **音声認識**: Speech Framework
- **テスト**: Swift Testing framework

### バックエンド
- **言語**: Go 1.24
- **フレームワーク**: Echo v4
- **実行環境**: AWS Lambda（Lambda Web Adapter）
- **AI**: OpenAI API

### インフラ
- **IaC**: Terraform
- **コンテナ**: Docker, AWS ECR
- **サーバーレス**: AWS Lambda + Function URL
- **CI/CD**: GitHub Actions（OIDC認証）

## 開発コマンド

### バックエンド

```bash
# ローカル起動
cd backend
cp .env.example .env  # OPENAI_API_KEYを設定
go run main.go

# テスト
go test ./...

# Docker ビルド
docker build -t zuntalk-backend .
```

### Terraform

```bash
# 初期化
cd terraform/environments/dev
terraform init

# プラン確認
export TF_VAR_openai_api_key="sk-proj-..."
terraform plan

# 適用
terraform apply

# フォーマット
terraform fmt -recursive
```

### iOS

```bash
# プロジェクトを開く
open ios/ZunTalk.xcodeproj

# テスト実行: Xcode > Product > Test (Cmd+U)
```

## APIエンドポイント

| メソッド | パス | 説明 |
|---------|------|------|
| POST | `/api/chat` | AI会話生成 |
| GET | `/api/info` | アプリ情報取得（メンテナンス状態、最小バージョン） |
| GET | `/api/error` | エラーテスト（Slack通知確認用） |
| GET | `/health` | ヘルスチェック |

### /api/chat リクエスト例

```json
{
  "messages": [
    {"role": "system", "content": "あなたはずんだもんです..."},
    {"role": "user", "content": "こんにちは！"}
  ],
  "model": "gpt-4o-mini",
  "maxTokens": 500
}
```

## 環境変数

### バックエンド（.env）
```
OPENAI_API_KEY=sk-proj-...   # 必須
PORT=8080                     # デフォルト
MAINTENANCE=false             # メンテナンスモード
MINIMUM_VERSION=1.0.0         # 最小アプリバージョン
```

### Terraform
```bash
export TF_VAR_openai_api_key="sk-proj-..."
export TF_VAR_region="ap-northeast-1"
```

### AWSアカウント構成
```
Shared: 448049807848  # ECR、GitHub Actions共通IAMロール
Dev:    039612872248  # 開発環境Lambda
Prod:   986921280333  # 本番環境Lambda
```

## デプロイ

### 自動デプロイ（GitHub Actions）
`backend/**`への変更がmainにマージされると自動でDev環境にデプロイ。
1. ECRにDockerイメージをプッシュ（sharedアカウント）
2. Lambda関数を更新（devアカウント）

### 手動デプロイ
GitHub Actionsから手動実行可能:
- **Dev**: `backend-deploy-dev.yml` → workflow_dispatch
- **Prod**: `backend-deploy-prod.yml` → workflow_dispatch（イメージタグを指定）

### デプロイ状況確認
`backend-status.yml`を実行すると、Dev/Prodの現在のイメージタグとECR内のイメージ一覧を確認可能。

## コーディング規約

### Swift
- SwiftUIの標準的なMVVMパターンを使用
- Repositoryパターンでデータアクセスを抽象化
- エラー型は各Repository内のError/ディレクトリに定義
- Keychainで機密情報（APIキー）を管理

### Go
- Echo標準のハンドラー/サービス構造
- 環境変数はconfig/config.goで一元管理
- エラーはログ出力してHTTPステータスコードで返却

### Terraform
- モジュール化（modules/ecr, modules/lambda）
- 環境別にenvironments/配下で分離
- 変数はvariables.tf、出力はoutputs.tfに定義

## 注意事項

- VOICEVOXフレームワーク、Open JTalk辞書、音声モデル（.vvm）はGit管理外
- iOS最小バージョン: 17.0、Xcode: 15.0以上
- Lambda Function URLはパブリックアクセス（CORS全許可）
- Terraform stateはS3に保存、DynamoDBでロック管理
