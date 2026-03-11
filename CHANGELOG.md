# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
