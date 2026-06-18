# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.2] - 2026-06-19

### Changed
- プライバシーポリシー・利用規約をアプリ内から開く際、ランディングサイトのヘッダー/フッターを非表示にする埋め込み表示（`?embed=1`）に対応 (#94)

### Fixed
- iOS 18 で deprecated になった `appStoreReceiptURL` による広告環境判定を `embedded.mobileprovision` の有無による判定に置き換え (#93)

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
