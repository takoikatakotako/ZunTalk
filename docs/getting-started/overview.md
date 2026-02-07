# プロジェクト概要

## ZunTalkとは

**ZunTalk**は、人気キャラクター「ずんだもん」とユーザーが音声で自然な会話を楽しめるiOSアプリケーションです。

### コンセプト

- 音声認識でユーザーの発話を理解
- AIが自然な応答を生成
- VOICEVOX技術でずんだもんの声で返答
- リアルタイムでの音声会話体験

## システム構成

```
┌─────────────┐
│  iOS App    │
│  (Swift)    │
└──────┬──────┘
       │ HTTPS
       ↓
┌─────────────┐
│ AWS Lambda  │
│   (Go)      │
└──────┬──────┘
       │ API
       ↓
┌─────────────┐
│  OpenAI     │
│    API      │
└─────────────┘
```

### コンポーネント

#### iOSアプリ
- **音声認識**: iOS Speech Framework
- **音声合成**: VOICEVOX Core
- **UI**: SwiftUI
- **最小iOS**: 17.0

#### バックエンド
- **フレームワーク**: Echo v4
- **実行環境**: AWS Lambda (Lambda Web Adapter)
- **AI**: OpenAI API (gpt-4o-mini/gpt-4o)

#### インフラ
- **IaC**: Terraform
- **コンテナ**: Docker, AWS ECR
- **ストレージ**: AWS S3 (VOICEVOXリソース)
- **CI/CD**: GitHub Actions (OIDC認証)

## 主な機能

### 1. AI会話生成
- OpenAI APIで自然な応答を生成
- モデル選択可能（gpt-4o-mini/gpt-4o）
- コンテキストを保持した会話

### 2. 音声合成
- VOICEVOX Coreによるずんだもんの声
- 高品質な音声生成
- バンドルから直接読み込み（高速化）

### 3. 音声認識
- iOS標準のSpeech Framework
- リアルタイム音声認識
- 日本語最適化

### 4. サーバーレス
- AWS Lambdaでスケーラブル
- コールドスタート対策
- コスト効率的

## ディレクトリ構造

```
ZunTalk/
├── ios/                    # iOSアプリ
│   ├── ZunTalk/           # ソースコード
│   │   ├── App/           # エントリーポイント
│   │   ├── Config/        # API設定
│   │   ├── Models/        # データモデル
│   │   ├── Repository/    # データアクセス層
│   │   └── Screens/       # UIビュー
│   ├── Development.xcconfig   # Debug環境設定
│   └── Production.xcconfig    # Release環境設定
├── backend/                # Goバックエンド
│   ├── main.go            # エントリーポイント
│   ├── handler/           # HTTPハンドラー
│   ├── service/           # ビジネスロジック
│   ├── model/             # データモデル
│   └── config/            # 環境変数管理
├── terraform/              # インフラ（IaC）
│   ├── modules/           # 再利用可能モジュール
│   └── environments/      # 環境別設定
├── docs/                   # ドキュメント
└── .github/workflows/      # CI/CD
```

## 開発の流れ

1. **機能開発**: ブランチを作成
2. **ローカルテスト**: シミュレータで動作確認
3. **PR作成**: レビュー依頼
4. **CI実行**: 自動テスト
5. **マージ**: mainブランチへ
6. **自動デプロイ**: Dev環境へ自動デプロイ

## 次のステップ

- [ローカル開発環境のセットアップ](../local-development.md)
- [ライブラリ管理](../libs-management.md)
- [アーキテクチャ詳細](../architecture/system.md)
