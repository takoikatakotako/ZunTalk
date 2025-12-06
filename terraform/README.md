# ZunTalk Terraform Configuration

ZunTalkのAWSインフラストラクチャをTerraformで管理します。

## ディレクトリ構成

```
terraform/
├── bootstrap/          # Terraform state管理用のS3・DynamoDBリソース
├── environments/       # 環境ごとの設定
│   ├── shared/        # 共有リソース（ECR）
│   ├── dev/           # 開発環境
│   ├── stg/           # ステージング環境
│   └── prod/          # 本番環境
└── modules/           # 再利用可能なモジュール
    ├── ecr/           # ECRリポジトリ
    └── lambda/        # Lambda関数 + Function URL
```

## セットアップ手順

### 1. Bootstrap（初回のみ）

Terraform stateを管理するためのS3バケットとDynamoDBテーブルを作成します。

```bash
cd terraform/bootstrap
terraform init
terraform plan
terraform apply
```

### 2. 共有リソース（ECR）のデプロイ

```bash
cd terraform/environments/shared
terraform init
terraform plan
terraform apply
```

### 3. 環境別リソースのデプロイ

#### Dev環境

```bash
cd terraform/environments/dev

# 環境変数でOpenAI APIキーを設定
export TF_VAR_openai_api_key="sk-proj-your_api_key_here"

terraform init
terraform plan
terraform apply
```

#### Stg環境

```bash
cd terraform/environments/stg
export TF_VAR_openai_api_key="sk-proj-your_api_key_here"
terraform init
terraform plan
terraform apply
```

#### Prod環境

```bash
cd terraform/environments/prod
export TF_VAR_openai_api_key="sk-proj-your_api_key_here"
terraform init
terraform plan
terraform apply
```

## デプロイフロー

### 初回セットアップ

1. Bootstrap（S3 + DynamoDB）
2. Shared（ECR）
3. Dev/Stg/Prod環境

### 通常のデプロイ

1. Dockerイメージをビルド
   ```bash
   cd backend
   docker build -t <account-id>.dkr.ecr.ap-northeast-1.amazonaws.com/zuntalk-backend:dev-latest .
   ```

2. ECRにプッシュ
   ```bash
   aws ecr get-login-password --region ap-northeast-1 | \
     docker login --username AWS --password-stdin <account-id>.dkr.ecr.ap-northeast-1.amazonaws.com

   docker push <account-id>.dkr.ecr.ap-northeast-1.amazonaws.com/zuntalk-backend:dev-latest
   ```

3. Lambdaを更新
   ```bash
   aws lambda update-function-code \
     --function-name zuntalk-backend-dev \
     --image-uri <account-id>.dkr.ecr.ap-northeast-1.amazonaws.com/zuntalk-backend:dev-latest
   ```

## 環境変数

各環境で以下の環境変数を設定する必要があります：

- `TF_VAR_openai_api_key`: OpenAI APIキー（必須）
- `TF_VAR_region`: AWSリージョン（デフォルト: ap-northeast-1）

## リソース概要

### Shared環境
- ECRリポジトリ（全環境で共有）

### 各環境（Dev/Stg/Prod）
- Lambda関数（コンテナイメージ）
- Lambda Function URL（パブリックHTTPSエンドポイント）
- CloudWatch Logs
- IAMロール・ポリシー

## モジュール仕様

### ECR Module
- リポジトリの作成
- イメージスキャン設定
- ライフサイクルポリシー（古いイメージの自動削除）

### Lambda Module
- コンテナベースのLambda関数
- Lambda Function URL（パブリックHTTPSエンドポイント）
- IAMロール作成
- CloudWatchログ設定
- 環境変数の設定
- CORS設定

## アーキテクチャについて

このプロジェクトではLambda Function URLを使用してHTTPSエンドポイントを公開しています。

### Lambda Function URLを選択した理由
- **シンプル** - API Gatewayの設定・管理が不要
- **コスト削減** - API Gatewayの料金が不要（Lambda実行コストのみ）
- **十分な機能** - CORS設定もでき、HTTPSも標準対応
- **個人開発に最適** - MVPや小規模アプリには十分

### 将来的にAPI Gatewayが必要になる場合
- カスタムドメインを使いたい
- WAFで保護したい
- 複雑なルーティング・認証が必要
- 使用量プランやAPIキー管理が必要

その場合は、Lambda Function URLを無効化してAPI Gatewayモジュールを追加することで対応可能です。

## 注意事項

- OpenAI APIキーは環境変数で渡すこと（コミットしない）
- S3バケット名は一意である必要があるため、必要に応じて変更すること
- Lambda Function URLはパブリックにアクセス可能なため、必要に応じてアプリ側で認証を実装すること

## クリーンアップ

リソースを削除する場合は、以下の順序で実行：

```bash
# 各環境のリソースを削除
cd terraform/environments/dev && terraform destroy
cd terraform/environments/stg && terraform destroy
cd terraform/environments/prod && terraform destroy

# 共有リソースを削除
cd terraform/environments/shared && terraform destroy

# Bootstrap（S3・DynamoDB）を削除
cd terraform/bootstrap && terraform destroy
```
