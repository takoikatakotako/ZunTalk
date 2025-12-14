# ZunTalk ドキュメント

このフォルダには、ZunTalkの法的文書が含まれています。

## ファイル一覧

- **terms-20251214.md** - 利用規約（初版: 2024年12月14日）
- **privacy-20251214.md** - プライバシーポリシー（初版: 2024年12月14日）

### バージョン管理

ファイル名に日付（YYYYMMDD形式）を含めることで更新履歴を管理します。
更新時は新しい日付でファイルを作成し、古いファイルはGit履歴として残します。

## リリース前にやること

### 1. 内容の確認と修正

両方のファイルで以下の項目を記入してください：

- `[日付を記入]` → 最終更新日
- `[運営者名を記入]` → 実際の運営者名
- `[メールアドレスを記入]` → お問い合わせ用メールアドレス
- `[住所を記入（任意）]` → 必要に応じて住所

### 2. 公開

これらのファイルをWeb上に公開する必要があります。選択肢：

- **GitHub Pages** (おすすめ)
- **S3 + CloudFront**
- **Notion公開ページ**

### 3. App Store申請

App Store Connect で以下のURLを登録：

- Privacy Policy URL: 公開したプライバシーポリシーのURL
- Terms of Service URL (任意): 公開した利用規約のURL

### 4. アプリ内のURL更新

`ios/ZunTalk/Screens/Onboarding/OnboardingView.swift` のダミーURLを実際のURLに変更：

```swift
// 現在（ダミー）
https://example.com/zuntalk/terms
https://example.com/zuntalk/privacy

// 変更後（例）
https://your-domain.com/terms-20251214.html
https://your-domain.com/privacy-20251214.html
```

**注意:** 規約を更新してファイル名（日付）が変わった場合、アプリ内のURLとApp Store登録URLも更新が必要です。

## 注意事項

- これらは叩き台です。必要に応じて弁護士や専門家に相談することをおすすめします
- 特に以下の点については確認が必要です：
  - AIサービスプロバイダ（Anthropic）のプライバシーポリシーへの言及
  - データ保存期間
  - 個人情報の取扱い
  - 準拠法と管轄裁判所
