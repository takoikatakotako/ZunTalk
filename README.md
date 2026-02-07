# ZunTalk

## 概要

ZunTalkは、AIを活用した音声通話アプリケーションなのだ！
ずんだもんと楽しく会話できるのだ！

## プロジェクト構成

このリポジトリはモノレポ構成になっています：

- `ios/` - iOSアプリケーション（Swift）
- `backend/` - バックエンドAPI（Go + Echo）

## 開発を始める

### クイックスタート

```bash
# リポジトリをクローン
git clone https://github.com/takoikatakotako/ZunTalk.git
cd ZunTalk

# VOICEVOXリソースをセットアップ（iOSアプリ開発の場合）
make setup-voicevox

# Xcodeでプロジェクトを開く
open ios/ZunTalk.xcodeproj
```

詳しいセットアップ手順は [docs/local-development.md](docs/local-development.md) を参照してください。

## 開発環境

### iOS
- Xcode 15.0以上
- iOS 17.0以上
- AWS CLI（VOICEVOXリソースのダウンロード用）

### Backend
- Go 1.21以上
- Echo v4

## Mermaidフローチャートテンプレート

### 基本的なアルゴリズムフローチャート

```mermaid
flowchart TD
    Start([画面遷移]) --> PlayRingbackTone[発信音再生]
    PlayRingbackTone --> ScriptGeneration[スクリプト生成]
    ScriptGeneration --> SplitText[テキスト分割<br/>。！？で分割]
    SplitText --> SynthesizeFirstChunk[最初のチャンク<br/>音声合成]
    SynthesizeFirstChunk --> ChunkLoop{次のチャンクあり?}
    ChunkLoop -->|あり| ParallelProcess[並行処理]
    ParallelProcess --> SynthesizeNext[次チャンク合成]
    ParallelProcess --> PlayCurrent[現チャンク再生]
    SynthesizeNext --> ChunkLoop
    PlayCurrent --> ChunkLoop
    ChunkLoop -->|なし| LastChunkPlay[最終チャンク再生]
    LastChunkPlay --> CallDuration{通話時間}
    CallDuration -->|2分未満| SpeechRecognition[音声認識]
    CallDuration -->|2分以上| End([終了])
    SpeechRecognition --> SilenceTimeout{2秒無音}
    SilenceTimeout -->|検出| ScriptGeneration
    SilenceTimeout -->|継続| SpeechRecognition
```

### CallStatus 状態遷移図

```mermaid
stateDiagram-v2
    [*] --> idle
    idle --> initializingVoiceVox: 初期化開始
    initializingVoiceVox --> requestingPermission: VoiceVoxセットアップ完了
    requestingPermission --> permissionGranted: 許可
    requestingPermission --> permissionDenied: 不許可
    permissionDenied --> [*]

    permissionGranted --> generatingScript: 最初のスクリプト生成
    generatingScript --> synthesizingVoice: スクリプト生成完了
    synthesizingVoice --> playingVoice: 音声合成完了
    playingVoice --> recognizingSpeech: 音声再生完了
    recognizingSpeech --> processingResponse: 音声認識完了
    processingResponse --> generatingScript: 応答スクリプト生成

    idle --> ended: 通話終了
    recognizingSpeech --> ended: 通話終了
    playingVoice --> ended: 通話終了
    ended --> [*]
```
