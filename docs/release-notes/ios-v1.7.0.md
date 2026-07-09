# iOS v1.7.0 リリースノート

対象コミット: `main`（PR #105〜#109 マージ済み）
提出日: 2026-07-09

技術的な変更の一覧は [CHANGELOG](../../CHANGELOG.md) を参照。

---

## App Store「このバージョンの新機能」（ユーザー向け・提出用）

```
ずんだもんの「エージェントモード」が使えるようになったのだ！

・3Dのずんだもんと音声で会話できるようになりました
・「今日の予定は？」と聞くと、iPhoneのカレンダーを見てずんだもんが教えてくれます
　（設定でGoogleアカウントを連携しているカレンダーの予定にも対応）
・設定画面からカレンダーへのアクセスをかんたんに許可・変更できます

そのほか、動作の安定性を改善しました。
これからもずんだもんをよろしくなのだ！
```

---

## GitHub Release 本文（タグ `ios/v1.7.0` を打った後に使用）

```markdown
## iOS v1.7.0

### Added
- ずんだもんエージェントモードを本番リリース（#105, #106, #107）
  - 3Dずんだもんと音声で会話し、カレンダーの予定を尋ねられる
  - カレンダー参照を Google Calendar API から **EventKit（iOS標準カレンダー）** に移行し、Google OAuth 審査を不要に。iOS に Google アカウントを同期していればその予定も読める
  - 設定画面にカレンダー連携セクションを追加（許可状態の表示・設定アプリへの導線）
  - deviceId ごとの日次利用回数制限でバックエンドのコストを保護
- 本番用の GCP 環境（Cloud Run / Firestore / Cloud Scheduler / APNs）を整備し、アプリを本番バックエンドへ接続（#108, #109）

### Changed
- Firestore を dev/prod で完全分離、エージェント API キーも dev/prod で別値化（#108, #109）
- 連絡先画面の表示崩れ（名前の折り返し）を修正

### Removed
- Gmail 連携（Google Sign-In）を全面削除。エージェントのツールはカレンダー（EventKit）に一本化（#107, #109）

**Full Changelog**: https://github.com/takoikatakotako/ZunTalk/compare/ios/v1.6.0...ios/v1.7.0
```

---

## 提出前チェックリスト

- [ ] App Store Connect のプライバシー栄養ラベルにカレンダーデータを追加
- [ ] プライバシーポリシー（takoikatakotako.github.io / PR #18）をマージして公開
- [ ] `ZunTalk-Production` スキーム・バージョン 1.7.0 でアーカイブ・アップロード
- [ ] TestFlight で動作確認（エージェント会話・カレンダー・電話予約）
- [ ] 審査提出
- [ ] アップロード成功後にタグ `ios/v1.7.0` を打つ → GitHub Release 作成
