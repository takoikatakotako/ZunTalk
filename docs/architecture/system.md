# システム構成

## 全体アーキテクチャ

```
┌──────────────────────────────────────────────────┐
│                   ユーザー                         │
└───────────────────┬──────────────────────────────┘
                    │
            ┌───────▼────────┐
            │   iOS App      │
            │   (SwiftUI)    │
            └───────┬────────┘
                    │
        ┌───────────┼───────────┐
        │           │           │
        ▼           ▼           ▼
  ┌─────────┐ ┌─────────┐ ┌────────┐
  │ Speech  │ │VOICEVOX │ │  API   │
  │Framework│ │  Core   │ │ Client │
  └─────────┘ └─────────┘ └────┬───┘
                                │ HTTPS
                                ▼
                    ┌───────────────────┐
                    │   AWS Lambda      │
                    │   (Go + Echo)     │
                    └────────┬──────────┘
                             │ API
                             ▼
                    ┌───────────────────┐
                    │   OpenAI API      │
                    │   (gpt-4o)        │
                    └───────────────────┘
```

## コンポーネント詳細

### 1. iOSアプリケーション

#### 責務
- ユーザーインターフェース
- 音声入出力
- AI会話の管理

#### 技術スタック
- **言語**: Swift
- **UI**: SwiftUI
- **最小iOS**: 17.0
- **アーキテクチャ**: MVVM + Repository パターン

#### 主要モジュール
- `TextGenerationRepository`: AI会話生成
- `TextToSpeechRepository`: 音声合成
- `SpeechRecognitionRepository`: 音声認識
- `KeychainRepository`: 認証情報管理

### 2. バックエンドAPI

#### 責務
- OpenAI APIとの通信
- リクエスト/レスポンスの変換
- エラーハンドリング

#### 技術スタック
- **言語**: Go 1.24
- **フレームワーク**: Echo v4
- **実行環境**: AWS Lambda + Lambda Web Adapter
- **デプロイ**: Docker + ECR

#### エンドポイント
- `POST /api/chat`: AI会話生成
- `GET /api/info`: アプリ情報取得
- `GET /health`: ヘルスチェック

### 3. インフラストラクチャ

#### AWS構成
- **Lambda**: サーバーレス実行環境
- **ECR**: Dockerイメージ管理
- **S3**: VOICEVOXリソース配信
- **IAM**: OIDC認証（GitHub Actions）

#### 環境分離
- **Shared** (448049807848): ECR、GitHub Actions IAM
- **Dev** (039612872248): 開発環境Lambda
- **Prod** (986921280333): 本番環境Lambda

## データフロー

### 会話フロー

1. **ユーザー音声入力**
   ```
   ユーザー → SpeechFramework → テキスト変換
   ```

2. **AI応答生成**
   ```
   テキスト → Lambda → OpenAI API → 応答テキスト
   ```

3. **音声合成**
   ```
   応答テキスト → VOICEVOX Core → 音声データ
   ```

4. **音声再生**
   ```
   音声データ → AVAudioPlayer → スピーカー
   ```

### VOICEVOXリソース配信フロー

```
開発時:
S3 → make setup-voicevox → ローカル

CI時:
S3 → GitHub Actions → Xcode Build → アプリバンドル
```

## セキュリティ

### 認証・認可
- **OpenAI API Key**: Keychainに安全に保存
- **Lambda URL**: パブリックアクセス（認証なし）
- **GitHub Actions**: OIDC認証（AWSへのアクセス）

### データ保護
- **通信**: HTTPS/TLS 1.2以上
- **ログ**: 個人情報は記録しない
- **キー管理**: iOS Keychain Services

## スケーラビリティ

### Lambda自動スケーリング
- リクエスト数に応じて自動スケール
- コールドスタート対策（最小実行時間確保）

### S3配信
- CloudFront連携可能
- 複数リージョン対応可能

## 監視・ログ

### CloudWatch
- Lambda実行ログ
- エラー率監視
- レスポンスタイム監視

### GitHub Actions
- CI/CDステータス
- デプロイ履歴

## パフォーマンス最適化

### iOS
- ✅ バンドルから直接読み込み（コピー不要）
- ✅ 未使用モデル削除（228MB削減）
- ✅ フォルダ参照でディレクトリ構造保持

### Lambda
- Docker Multi-stage build
- Lambda Web Adapter
- 環境変数キャッシュ

## 障害対策

### 可用性
- Lambda自動復旧
- S3の高可用性（99.99%）

### フェイルセーフ
- API呼び出し失敗時も動作継続
- オフライン対応（ローカルキャッシュ）
