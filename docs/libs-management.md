# 外部ライブラリ管理ガイド

このドキュメントでは、ZunTalkで使用する外部ライブラリ（VOICEVOX等）の管理方法について説明します。

## 概要

ZunTalkは、音声合成に必要な大容量のバイナリファイルをGit管理外で扱います。これらのリソースは以下の場所で管理されます：

- **ローカル開発**: `libs/` ディレクトリ（Git管理外）
- **CI/CD**: AWS S3バケット `zuntalk-resources`（Shared環境）

## S3バケットからローカルへのコピー

開発環境でVOICEVOXリソースが必要な場合、S3から直接ダウンロードできます。

```bash
# AWSプロファイルを設定
export AWS_PROFILE=charalarm-management-sso

# S3からlibsディレクトリに同期
aws s3 sync s3://zuntalk-resources/ libs/

# 内容確認
ls -R libs/
```

## S3バケットへのコピー

VOICEVOXリソースを更新してS3にアップロードする手順です。

### 1. VOICEVOXリソースの準備

#### Open JTalk辞書とモデルのダウンロード

```bash
# voicevoxディレクトリを作成
mkdir -p libs/voicevox
cd libs/voicevox

# VOICEVOX公式のダウンローダーをダウンロード
# https://github.com/VOICEVOX/voicevox_core/releases から最新版を取得
# 例: download-osx-arm64 など

# ダウンローダーを実行して辞書とモデルをダウンロード
chmod +x download-osx-arm64
./download-osx-arm64

# ダウンロードされたディレクトリ末尾にバージョンを追記
mv voicevox_core voicevox_core-0.16.3
```

#### VOICEVOX Core フレームワークの追加

```bash
# voicevox_core.xcframework をダウンロード
# https://github.com/VOICEVOX/voicevox_core/releases から iOS用をダウンロード

# 解凍してvoicevoxディレクトリに配置
unzip voicevox_core-iOS-*.zip
mv voicevox_core.xcframework libs/voicevox/voicevox_core-0.16.3/
```

#### ONNX Runtime フレームワークの追加（必要に応じて）

```bash
# voicevox_onnxruntime.xcframework をダウンロード
# https://github.com/VOICEVOX/voicevox_onnxruntime-ios-xcframework/releases

# 解凍してvoicevoxディレクトリに配置
unzip voicevox_onnxruntime-*.zip
mv voicevox_onnxruntime.xcframework libs/voicevox/voicevox_core-0.16.3/
```

### 2. S3へアップロード

リソースの準備ができたら、S3にアップロードします。

```bash
# AWSプロファイルを設定
export AWS_PROFILE=charalarm-management-sso

# Dry run: 何がアップロードされるか確認（実際にはアップロードしない）
aws s3 sync libs/ s3://zuntalk-resources/ \
  --dryrun \
  --exclude ".DS_Store" \
  --exclude "*/.DS_Store"

# 問題なければ本番アップロード
aws s3 sync libs/ s3://zuntalk-resources/ \
  --exclude ".DS_Store" \
  --exclude "*/.DS_Store"

# アップロード結果を確認
aws s3 ls s3://zuntalk-resources/ --recursive --human-readable
```

### 3. アップロード後の確認

```bash
# S3バケットの内容を確認
aws s3 ls s3://zuntalk-resources/ --recursive

# バージョン情報も確認（バージョニング有効のため）
aws s3api list-object-versions \
  --bucket zuntalk-resources \
  --max-items 10
```