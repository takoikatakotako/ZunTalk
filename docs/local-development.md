# ローカル開発環境セットアップガイド

このドキュメントでは、ZunTalkをローカルで開発するための環境構築手順を説明します。

## 前提条件

### 必須ツール

- **Xcode**: 15.0以上
- **Git**: バージョン管理
- **AWS CLI**: S3からリソースをダウンロードするため
- **Make**: セットアップスクリプト実行用（macOSに標準搭載）

### AWS認証情報の設定

VOICEVOXリソースはS3バケット（`zuntalk-resources`）に保存されています。アクセスするにはAWS認証情報が必要です。

```bash
# AWSプロファイルを設定（既存の場合）
export AWS_PROFILE=your-profile-name

# または、AWS CLIで新規設定
aws configure
```

**必要な権限:**
- `s3:GetObject` on `arn:aws:s3:::zuntalk-resources/*`
- `s3:ListBucket` on `arn:aws:s3:::zuntalk-resources`

## クイックスタート

### 1. リポジトリをクローン

```bash
git clone https://github.com/takoikatakotako/ZunTalk.git
cd ZunTalk
```

### 2. VOICEVOXリソースをセットアップ

```bash
# Makefileを使用して自動セットアップ
make setup-voicevox
```

このコマンドは以下を実行します:
1. S3から`libs/`ディレクトリにVOICEVOXリソースをダウンロード
2. xcframeworkを`ios/Voicevox/`にコピー
3. Open JTalk辞書を`ios/ZunTalk/`にコピー
4. 音声モデル（.vvm）を`ios/ZunTalk/vvms/`にコピー

### 3. Xcodeでプロジェクトを開く

```bash
open ios/ZunTalk.xcodeproj
```

### 4. ビルド＆実行

Xcode上で:
1. スキーム: `ZunTalk-Development` を選択
2. シミュレーターまたは実機を選択
3. `Cmd + R` でビルド＆実行

## Makefileコマンド一覧

```bash
# ヘルプを表示
make help

# VOICEVOXリソースをセットアップ
make setup-voicevox

# ダウンロードしたリソースを削除
make clean-voicevox
```

## 手動セットアップ（Makefileを使わない場合）

### 1. S3からダウンロード

```bash
# AWSプロファイルを設定
export AWS_PROFILE=your-profile-name

# S3から同期
aws s3 sync s3://zuntalk-resources/ libs/ \
  --exclude ".DS_Store" \
  --exclude "*/.DS_Store"
```

### 2. iOSプロジェクトにコピー

```bash
# 既存のフレームワークを削除
rm -rf ios/Voicevox/voicevox_core.xcframework
rm -rf ios/Voicevox/voicevox_onnxruntime.xcframework

# xcframeworkをコピー
rsync -a libs/voicevox_core/voicevox_core-0.16.3/voicevox_core.xcframework ios/Voicevox/
rsync -a libs/voicevox_onnxruntime-ios-xcframework/voicevox_onnxruntime-ios-xcframework-1.17.3/voicevox_onnxruntime.xcframework ios/Voicevox/

# Open JTalk辞書をコピー
rsync -a libs/voicevox_core/voicevox_core-0.16.3/dict/open_jtalk_dic_utf_8-1.11 ios/ZunTalk/

# 音声モデルをコピー
mkdir -p ios/ZunTalk/vvms
cp libs/voicevox_core/voicevox_core-0.16.3/models/vvms/*.vvm ios/ZunTalk/vvms/
```

## セットアップの確認

以下のディレクトリ/ファイルが存在することを確認してください:

```bash
# xcframeworks
ls -la ios/Voicevox/voicevox_core.xcframework
ls -la ios/Voicevox/voicevox_onnxruntime.xcframework

# Open JTalk辞書
ls -la ios/ZunTalk/open_jtalk_dic_utf_8-1.11

# 音声モデル
ls -la ios/ZunTalk/vvms/*.vvm
```

すべてのファイルが存在すれば、セットアップ完了です！

## トラブルシューティング

### AWS認証エラーが発生する

```
Unable to locate credentials
```

**解決策:**
1. AWS CLIが正しくインストールされているか確認: `aws --version`
2. プロファイルを設定: `export AWS_PROFILE=your-profile-name`
3. 認証情報を確認: `aws sts get-caller-identity`

### S3バケットにアクセスできない

```
An error occurred (AccessDenied) when calling the ListObjectsV2 operation
```

**解決策:**
IAM権限を確認してください。以下の権限が必要です:
- `s3:GetObject` on `arn:aws:s3:::zuntalk-resources/*`
- `s3:ListBucket` on `arn:aws:s3:::zuntalk-resources`

### Xcodeでxcframeworkが見つからない

```
There is no XCFramework found at '.../voicevox_core.xcframework'
```

**解決策:**
1. `make clean-voicevox` で既存のリソースを削除
2. `make setup-voicevox` で再セットアップ
3. Xcodeを再起動

### ビルドエラー: No such module 'FoundationModels'

```
No such module 'FoundationModels'
```

**原因:**
iOS 26+ でのみ利用可能なFoundationModelsフレームワークを参照しています。

**解決策:**
iOS 18以降のシミュレーター/実機を使用している場合、これは正常です。条件付きコンパイルにより、iOS 26未満では自動的にフォールバックされます。ビルドは成功するはずです。

## バックエンド開発

バックエンド（Go）の開発については、[backend/README.md](../backend/README.md) を参照してください。

### 簡易起動

```bash
cd backend
cp .env.example .env
# .env ファイルでOPENAI_API_KEYを設定
go run main.go
```

## 関連ドキュメント

- [外部ライブラリ管理ガイド](./libs-management.md) - S3へのアップロード方法
- [API仕様書](./api/openapi.yaml) - バックエンドAPIの仕様
- [CLAUDE.md](../CLAUDE.md) - プロジェクト概要
