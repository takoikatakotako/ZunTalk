#!/bin/bash

# VOICEVOXリソースをS3にアップロードするスクリプト
# 初回セットアップ時に実行する

set -e

# カラー出力
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 設定
S3_BUCKET="zuntalk-resources"
S3_PREFIX="voicevox"
VOICEVOX_DIR="ios/ZunTalk/Frameworks/voicevox_core.xcframework"
OPEN_JTALK_DIR="ios/ZunTalk/Resources/open_jtalk_dic_utf_8-1.11"
MODELS_DIR="ios/ZunTalk/Resources/Models"

echo -e "${GREEN}VOICEVOXリソースをS3にアップロードします${NC}"
echo "S3 Bucket: s3://${S3_BUCKET}/${S3_PREFIX}/"
echo ""

# AWSプロファイル確認
if [ -z "$AWS_PROFILE" ]; then
    echo -e "${YELLOW}AWS_PROFILEが設定されていません。デフォルトプロファイルを使用します。${NC}"
    echo -e "${YELLOW}特定のプロファイルを使用する場合は、AWS_PROFILE=profile-name を設定してください。${NC}"
    echo ""
fi

# VOICEVOXフレームワークの圧縮とアップロード
echo -e "${GREEN}1. VOICEVOXフレームワークを圧縮しています...${NC}"
if [ ! -d "$VOICEVOX_DIR" ]; then
    echo -e "${RED}エラー: $VOICEVOX_DIR が見つかりません${NC}"
    exit 1
fi

cd ios/ZunTalk/Frameworks
zip -r -q voicevox_core.xcframework.zip voicevox_core.xcframework
echo -e "${GREEN}✓ 圧縮完了${NC}"

echo -e "${GREEN}2. VOICEVOXフレームワークをS3にアップロードしています...${NC}"
aws s3 cp voicevox_core.xcframework.zip "s3://${S3_BUCKET}/${S3_PREFIX}/voicevox_core.xcframework.zip"
rm voicevox_core.xcframework.zip
echo -e "${GREEN}✓ アップロード完了${NC}"
cd ../../..

# Open JTalk辞書の圧縮とアップロード
echo -e "${GREEN}3. Open JTalk辞書を圧縮しています...${NC}"
if [ ! -d "$OPEN_JTALK_DIR" ]; then
    echo -e "${RED}エラー: $OPEN_JTALK_DIR が見つかりません${NC}"
    exit 1
fi

cd ios/ZunTalk/Resources
zip -r -q open_jtalk_dic_utf_8-1.11.zip open_jtalk_dic_utf_8-1.11
echo -e "${GREEN}✓ 圧縮完了${NC}"

echo -e "${GREEN}4. Open JTalk辞書をS3にアップロードしています...${NC}"
aws s3 cp open_jtalk_dic_utf_8-1.11.zip "s3://${S3_BUCKET}/${S3_PREFIX}/open_jtalk_dic_utf_8-1.11.zip"
rm open_jtalk_dic_utf_8-1.11.zip
echo -e "${GREEN}✓ アップロード完了${NC}"
cd ../../..

# 音声モデルのアップロード
echo -e "${GREEN}5. 音声モデルをS3にアップロードしています...${NC}"
if [ ! -d "$MODELS_DIR" ]; then
    echo -e "${RED}エラー: $MODELS_DIR が見つかりません${NC}"
    exit 1
fi

aws s3 sync "$MODELS_DIR" "s3://${S3_BUCKET}/${S3_PREFIX}/models/" --exclude "*.DS_Store"
echo -e "${GREEN}✓ アップロード完了${NC}"

echo ""
echo -e "${GREEN}すべてのリソースのアップロードが完了しました！${NC}"
echo ""
echo "アップロードされたファイル:"
echo "  - s3://${S3_BUCKET}/${S3_PREFIX}/voicevox_core.xcframework.zip"
echo "  - s3://${S3_BUCKET}/${S3_PREFIX}/open_jtalk_dic_utf_8-1.11.zip"
echo "  - s3://${S3_BUCKET}/${S3_PREFIX}/models/"
echo ""
echo "S3バケットの内容を確認:"
echo "  aws s3 ls s3://${S3_BUCKET}/${S3_PREFIX}/ --recursive"
