# ZunTalk ドキュメント

**ZunTalk**は、ずんだもんとユーザーが音声で会話できるiOSアプリです。

## 主な機能

### 🗣️ AI会話
OpenAI API（gpt-4o-mini/gpt-4o）を使用して、自然な会話を実現

### 🎤 音声認識
iOS SpeechFrameworkでユーザーの音声を認識

### 🔊 音声合成
VOICEVOX Coreでずんだもんの声を生成

### ☁️ サーバーレス
AWS Lambda（チャットAPI）+ GCP Cloud Run（エージェント・電話予約）でスケーラブルなバックエンド

### 🤖 エージェントモード
Vertex AI（Gemini）が司令塔となり、EventKit カレンダー等の端末ツールを組み合わせて応答

### 📞 電話予約
指定時刻にずんだもんから VoIP 着信（Cloud Run + Firestore + Cloud Scheduler + APNs）

## クイックスタート

### 必要な環境

- macOS（Xcode開発用）
- Xcode 15.0以上
- iOS 17.0以上
- AWS CLI
- Terraform

### セットアップ

1. **リポジトリのクローン**
   ```bash
   git clone https://github.com/takoikatakotako/ZunTalk.git
   cd ZunTalk
   ```

2. **VOICEVOXリソースのダウンロード**
   ```bash
   make setup-voicevox
   ```

3. **Xcodeでプロジェクトを開く**
   ```bash
   open ios/ZunTalk.xcodeproj
   ```

詳しくは [ローカル開発環境](local-development.md) をご覧ください。

## ドキュメント構成

- **はじめに**: プロジェクト概要、セットアップ方法
- **アーキテクチャ**: システム構成、各コンポーネントの詳細
- **API**: APIエンドポイントの仕様
- **開発ガイド**: コーディング規約、CI/CD、デプロイ方法

## 技術スタック

### iOS
- Swift
- SwiftUI
- VOICEVOX Core
- Speech Framework

### バックエンド
- Go 1.24
- Echo v4
- AWS Lambda（チャットAPI）+ OpenAI API
- GCP Cloud Run（エージェント・電話予約）+ Vertex AI（Gemini）

### インフラ
- AWS (Lambda, ECR, S3)
- GCP (Cloud Run, Firestore, Cloud Scheduler, Secret Manager)
- Terraform
- GitHub Actions

## リンク

- [GitHubリポジトリ](https://github.com/takoikatakotako/ZunTalk)
- [API仕様書](api/specification.md)
- [ローカル開発環境](local-development.md)

## ライセンス

このプロジェクトのライセンスについては、リポジトリをご確認ください。
