# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.7.0]

### Added
- エージェントモードを本番でも有効化（#105, #106, #107）
  - カレンダーツールを Google Calendar API から **EventKit（iOS 標準カレンダー）** に移行し、Google OAuth 審査を不要にした。Google アカウント同期済みの予定も読める
  - 端末が実行可能なツールを申告する capability ネゴシエーションを追加（現状は `calendar` のみ）
  - deviceId ごとの `/agent` 日次利用回数制限（`AGENT_DAILY_LIMIT`、デフォルト50）で Vertex AI のコスト保護。上限超過は 429 でずんだもん口調のメッセージを表示
- プライバシーポリシーにカレンダーデータの扱いを追記
- prod GCP 環境を完全化（電話予約インフラ一式）し、本番アプリを prod Cloud Run へ切り替え（#108）

### Changed
- `FeatureFlags` を分割: `agentModeEnabled` を本番でも有効に、開発者向け UI（エージェントテスト・表情確認）は `debugToolsEnabled`（Debug 限定）に分離
- Firestore を dev/prod で分離。接続先DBを `FIRESTORE_DATABASE` で切り替え（dev=`(default)` / prod=`zuntalk-prod`）。各環境が自分のDB・インデックス・TTL を所有し、prod のプロジェクト分割にコード変更なしで対応できる構成に（#108）

### Removed
- Gmail 連携（Google Sign-In）を全面削除。設定画面の Google 連携 UI・`GoogleAuthManager`・`GmailTool`・`gmail` capability、GoogleSignIn SDK と OAuth 設定（client ID・URL スキーム）を撤去。カレンダーは EventKit のみで完結（Firebase / AdMob は影響なし）

## [1.6.0] - 2026-07-06

### Added
- 指定した時刻にずんだもんから電話がかかってくる「電話の予約」機能（#99, #100）
  - 連絡先画面の予約ボタンから時刻を指定すると、VoIP push + CallKit のネイティブ着信 UI で電話がかかってくる（ロック中・アプリ終了中でも着信）
  - 応答後、会話の準備が整うまで呼び出し音を再生
  - 予約は1件まで（キャンセルして取り直し可能）
  - バックエンドは Cloud Run（Go）+ Firestore + Cloud Scheduler + APNs 直叩き（Terraform 管理）
- ずんだもんエージェントモードの基盤（3Dずんだもん表示・Vertex AI Gemini・Gmail/Calendar 連携）（#100）
  - Google OAuth 審査が通るまで本番ビルドでは `FeatureFlags` により非表示（Development ビルドのみ有効）

### Changed
- Firebase 設定ファイル（GoogleService-Info）を Development / Production で分離し、git 管理外に変更（CI は S3 から取得）。Google API キーには iOS bundle ID 制限を適用
- `appStoreReceiptURL` の deprecation に対応（#93）

## [1.5.1] - 2026-06-11

### Changed
- 輸出コンプライアンスの自己申告キー（`ITSAppUsesNonExemptEncryption`）を追加し、アップロード時の暗号化に関する質問をスキップ（#88）

### Fixed
- ビルド設定ファイル（`Development.xcconfig` / `Production.xcconfig`）がアプリバンドルに同梱されていた問題を修正（Copy Bundle Resources から除外）（#89）

## [1.5.0] - 2026-06-06

### Added
- AdMob バナー広告を導入（連絡先リスト下部に表示）
- App Store 向けランディングページを追加し、ドキュメントを `/docs/` 配下で公開

### Changed
- 共有 OIDC プロバイダを data 参照に変更（dev/prod）
- GitHub Actions を Node.js 24 対応版へ更新
- Lambda のシークレットを SSM パラメータから解決するよう変更

## [1.4.1] - 2026-05-12

### Fixed
- 着信音が取得できない場合でも通話を継続するよう修正（失敗は Crashlytics に記録）

## [1.4.0] - 2026-05-03

### Added
- Firebase Analytics のイベント計測を実装
- Firebase Crashlytics を有効化してエラーを記録

### Fixed
- CI 安定化（UI テストの起動タイムアウト延長、SwiftLint 対応）

## [1.3.0] - 2026-03-29

### Added
- テキストチャット機能を追加
- チャット画面に VOICEVOX 音声再生と初回挨拶を追加
- チャットの最大会話回数を往復40回に制限
- Firebase Analytics / Crashlytics を導入
- SwiftLint を導入してコード品質を改善
- OpenAI API リクエストに Exponential Backoff リトライを追加
- ChatViewModel のユニットテストとバックエンド Go テストの CI を追加

### Changed
- リトライロジックを hashicorp/go-retryablehttp に置き換え

### Fixed
- チャット画面の音声停止・エラーハンドリングを改善

## [1.2.0] - 2026-02-17

### Added
- 完全オフライン対応（機内モードでも起動可能）
- ネットワーク状態を監視するNetworkRepositoryを追加
- 古いVOICEVOXリソースを自動削除するマイグレーション処理
- リリースフローのドキュメント

### Changed
- オフライン時はAPI呼び出しをスキップして即座に起動

### Fixed
- 既存ユーザーのデバイスに残っていた約300MBの不要なVOICEVOXリソースを自動削除

## [1.1.0] - 2025-XX-XX

### Added
- MkDocsでドキュメントサイトを構築
- VOICEVOXリソースをバンドルから直接読み込み

### Changed
- VOICEVOXリソースのコピー処理を削除（起動時間短縮）

## [1.0.1] - 2025-XX-XX

### Fixed
- 各種バグフィックス

## [1.0.0] - 2025-XX-XX

### Added
- 初回リリース
- ずんだもんとの音声会話機能
- OpenAI APIによるAI応答生成
- VOICEVOX Coreによる音声合成
- iOS Speech Frameworkによる音声認識
