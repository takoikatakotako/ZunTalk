# リリースフロー

ZunTalkのリリース手順を説明します。

## iOSアプリのリリースフロー

### 1. リリースブランチの作成

mainブランチから新しいリリースブランチを作成します。

```bash
git checkout main
git pull
git checkout -b release/ios/{version}
```

**命名規則:** `release/ios/{version}` (例: `release/ios/1.2.0`)

### 2. バージョン番号の更新

以下のファイルでバージョン番号を更新します：

- `ios/ZunTalk/Info.plist`
  - `CFBundleShortVersionString`: マーケティングバージョン (例: 1.2.0)
  - `CFBundleVersion`: ビルド番号 (例: 1)

バージョニング規則：
- セマンティックバージョニング: `MAJOR.MINOR.PATCH`
  - **MAJOR**: 破壊的変更、大規模な機能追加
  - **MINOR**: 後方互換性のある機能追加
  - **PATCH**: バグフィックス

### 3. CHANGELOGの更新

`CHANGELOG.md` を更新します（作成されていない場合は作成）。

```markdown
## [1.2.0] - 2026-02-17

### Added
- 完全オフライン対応（機内モードでも起動可能）
- 古いVOICEVOXリソースを自動削除するマイグレーション処理

### Changed
- ネットワーク状態を監視するNetworkRepositoryを追加

### Fixed
- (該当する場合)
```

### 4. コミット & プッシュ

```bash
git add .
git commit -m "chore: bump version to 1.2.0"
git push -u origin release/ios/1.2.0
```

### 5. Archive & TestFlightアップロード

1. Xcodeでプロジェクトを開く
2. スキームを **Release** に変更
3. **Product > Archive** を実行
4. Archiveが成功したら、**Distribute App** を選択
5. **App Store Connect** を選択してTestFlightにアップロード

### 6. TestFlightでのテスト

- 社内テスト: 開発チームで動作確認
- 外部テスト: ベータテスターで確認（必要に応じて）

### 7. mainブランチへのマージ

テストが完了したら、mainにマージします。

```bash
# GitHubでPRを作成してマージ、またはローカルでマージ
git checkout main
git merge release/ios/1.2.0
git push origin main
```

### 8. タグの作成

mainブランチでリリースタグを作成します。

```bash
git checkout main
git pull
git tag -a ios/v1.2.0 -m "iOS v1.2.0 release"
git push origin ios/v1.2.0
```

**命名規則:** `ios/v{version}` (例: `ios/v1.2.0`)

### 9. リリースブランチの削除

```bash
git branch -d release/ios/1.2.0
git push origin --delete release/ios/1.2.0
```

### 10. App Store申請（必要に応じて）

1. App Store Connectで新しいバージョンを作成
2. スクリーンショット、説明文などを更新
3. 審査に提出

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

- [ ] リリースブランチ作成 (`release/ios/{version}`)
- [ ] バージョン番号更新（Info.plist）
- [ ] CHANGELOG更新
- [ ] Archive成功
- [ ] TestFlightアップロード成功
- [ ] 社内テスト完了

### iOSリリース後

- [ ] mainにマージ
- [ ] タグ作成 (`ios/v{version}`)
- [ ] リリースブランチ削除
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
