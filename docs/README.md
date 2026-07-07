# ZunTalk ドキュメント

このフォルダには、ZunTalk の開発ドキュメントと法的文書に関する情報が含まれています。

## ドキュメント構成

- `getting-started/` — プロジェクト概要、セットアップ
- `architecture/` — システム構成（[system.md](architecture/system.md)）、iOS アーキテクチャ
- `api/` — チャットAPI 仕様（[specification.md](api/specification.md)）、OpenAPI
- `development/` — CI/CD、リリース手順
- `local-development.md` / `libs-management.md` — ローカル開発・ライブラリ管理

エージェント・電話予約バックエンドの仕様は [agent/README.md](../agent/README.md) を参照してください。

## 法的文書（利用規約・プライバシーポリシー）の公開URL

アプリが実際にリンクしているのは **ZunTalk リポジトリの `landing/` を GitHub Pages で配信** した以下のURLです（`OnboardingView.swift` / `ConfigView.swift`）。

- **利用規約**: https://takoikatakotako.github.io/ZunTalk/terms.html
- **プライバシーポリシー**: https://takoikatakotako.github.io/ZunTalk/privacy.html

配信元は本リポジトリの `landing/terms.html` / `landing/privacy.html`（`.github/workflows/docs.yml` でデプロイ）。App Store Connect の Privacy Policy URL / Terms of Service URL にも同じURLを登録します。

### ⚠️ 二重管理に注意

別リポジトリ `takoikatakotako.github.io` にも同内容のコピー（`docs/projects/zuntalk/privacy.html`、公開URL `https://takoikatakotako.github.io/projects/zuntalk/privacy.html`）が存在します。**プライバシーポリシーを更新したら両方を揃える**こと（アプリのリンク先は前者だが、旧URLが外部から参照されている可能性があるため）。

## 規約を更新する場合

1. 本リポジトリの `landing/privacy.html`（および `landing/privacy.md` 等）を更新
2. `takoikatakotako.github.io` 側の `docs/projects/zuntalk/` のコピーも同内容に更新
3. URL は変更しないことを推奨（変更する場合は `OnboardingView.swift` / `ConfigView.swift` と App Store Connect の URL、アップデート申請も必要）

## 注意事項

- 重要な変更を行った場合は、既存ユーザーへの通知を検討してください
- 必要に応じて弁護士や専門家に相談することをおすすめします
