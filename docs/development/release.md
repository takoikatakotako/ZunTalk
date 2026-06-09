# リリースフロー

ZunTalkのリリース手順を説明します。

## iOSアプリのリリースフロー

**トランクベース + タグ**で運用します。`main` を常にリリース可能な状態に保ち、長命なリリースブランチは作りません。各リリースは `main` 上のコミットに打つタグ `ios/v{version}` で確定します。

### 1. バージョン番号の更新（短命ブランチ）

`main` から短命の作業ブランチを作成します（リリースブランチは作りません）。

```bash
git checkout main
git pull
git checkout -b chore/bump-version-{version}
```

**命名規則の例:** `chore/bump-version-1.5.0`

以下でバージョン番号を更新します：

- `ios/ZunTalk.xcodeproj/project.pbxproj`
  - `MARKETING_VERSION`: マーケティングバージョン（アプリ本体ターゲットの Debug / Release の2箇所、例: `1.5.0`）
  - `CURRENT_PROJECT_VERSION`: ビルド番号（同一マーケティングバージョンで再アップロードする場合のみ増やす）

> バージョンは `Info.plist` ではなくビルド設定（`MARKETING_VERSION`）が真実。`Info.plist` は値を持ちません。

バージョニング規則：
- セマンティックバージョニング: `MAJOR.MINOR.PATCH`
  - **MAJOR**: 破壊的変更、大規模な機能追加
  - **MINOR**: 後方互換性のある機能追加
  - **PATCH**: バグフィックス

### 2. CHANGELOGの更新

`CHANGELOG.md` の先頭に新しいバージョンのエントリを追加します。

```markdown
## [1.5.0] - 2026-06-06

### Added
- AdMob バナー広告を導入（連絡先リスト下部に表示）

### Changed
- (該当する場合)

### Fixed
- (該当する場合)
```

### 3. PR 作成 & main へマージ

```bash
git add .
git commit -m "chore: bump version to {version}"
git push -u origin chore/bump-version-{version}
```

GitHub で PR を作成し、CI が通ったら `main` へマージします。`main` は常にリリース可能な状態を保ちます。

### 4. Archive & App Store Connect アップロード

`main` の最新コミット（リリースに含めたい変更がすべてマージ済みの状態）から Archive します。

1. `git checkout main && git pull` で最新に同期
2. Xcode でスキームを **Release** に変更
3. ターゲットを **Any iOS Device (arm64)** に設定
4. **Product > Archive** を実行
5. Organizer で **Distribute App → App Store Connect → Upload**

### 5. タグの作成（アップロード成功後）

アップロードが成功したら、**提出したコミット**にタグを打ちます。出荷していないコミットにタグを残さないため、Archive 前ではなくアップロード成功後に打ちます。

```bash
git checkout main
git pull
git tag -a ios/v{version} -m "iOS v{version} release"
git push origin ios/v{version}
```

**命名規則:** `ios/v{version}` (例: `ios/v1.5.0`)

### 6. TestFlight / App Store 申請

1. TestFlight で動作確認（必要に応じて社内/外部テスト）
2. App Store Connect で新しいバージョンを作成
3. スクリーンショット、説明文、「このバージョンの新機能」を更新
4. 審査に提出

> TestFlight 配信ビルドは `sandboxReceipt` 判定で自動的にテスト広告を表示します。実広告が出るのは App Store 公開ビルドのみです。

### Hotfix

公開済みバージョンの緊急修正は、対象タグから枝を切って対応します。

```bash
git checkout -b hotfix/ios-{patch-version} ios/v{released-version}
# 修正をコミット → PR で main へマージ → 上記 1〜5 の手順で {patch-version} をリリース
```

---

## バックエンドのリリースフロー

バックエンドは**GitHub Actions**で自動化されています。

### Dev環境へのデプロイ（自動）

`backend/**` への変更がmainブランチにマージされると、自動的にDev環境にデプロイされます。

**ワークフロー:** `.github/workflows/backend-deploy-dev.yml`

1. ECRにDockerイメージをプッシュ（sharedアカウント）
2. Lambda関数を更新（devアカウント）

### Prod環境へのデプロイ（手動）

GitHub Actionsから手動で実行します。

**ワークフロー:** `.github/workflows/backend-deploy-prod.yml`

1. GitHub Actionsの **Actions** タブを開く
2. `Backend Deploy - Prod` ワークフローを選択
3. **Run workflow** をクリック
4. デプロイするイメージタグを指定（例: `main-a1b2c3d`）
5. 実行

### デプロイ状況の確認

**ワークフロー:** `.github/workflows/backend-status.yml`

現在のDev/Prod環境のイメージタグとECR内のイメージ一覧を確認できます。

### バージョンタグの作成

バックエンドのリリース時は、タグを作成します。

```bash
git checkout main
git pull
git tag -a backend/v1.0.1 -m "Backend v1.0.1 release"
git push origin backend/v1.0.1
```

**命名規則:** `backend/v{version}` (例: `backend/v1.0.1`)

---

## リリースチェックリスト

### iOSリリース前

- [ ] バージョン番号更新（`project.pbxproj` の `MARKETING_VERSION`）
- [ ] CHANGELOG更新
- [ ] PR を作成し CI 通過後に main へマージ
- [ ] main を最新に同期して Archive 成功
- [ ] App Store Connect アップロード成功

### iOSリリース後

- [ ] タグ作成 (`ios/v{version}`、アップロード成功後に main へ)
- [ ] TestFlight で動作確認
- [ ] App Store申請（必要に応じて）

### バックエンドリリース前

- [ ] 変更内容の確認
- [ ] Dev環境でのテスト完了

### バックエンドリリース後

- [ ] Prod環境へデプロイ
- [ ] タグ作成 (`backend/v{version}`)
- [ ] デプロイ確認

---

## トラブルシューティング

### Archiveが失敗する

- コード署名の設定を確認
- Provisioning Profileが最新か確認
- Xcodeのクリーン（Shift + Cmd + K）を実行

### TestFlightアップロードが失敗する

- App Store Connectのアカウント権限を確認
- バージョン番号が重複していないか確認

### Lambda関数の更新が反映されない

- デプロイ状況を確認（backend-status.yml）
- イメージタグが正しいか確認
- Lambda関数のログを確認（CloudWatch Logs）
