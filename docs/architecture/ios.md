# iOSアプリアーキテクチャ

## 概要

ZunTalkのiOSアプリは、SwiftUIとMVVMパターンを採用したモダンなアーキテクチャで構築されています。

## アーキテクチャパターン

### MVVM + Repository

```
View ← ViewModel ← Repository ← API/Framework
```

**責務分離:**
- **View**: UI表示のみ
- **ViewModel**: ビジネスロジック、状態管理
- **Repository**: データアクセス抽象化

## ディレクトリ構造

```
ZunTalk/
├── App/                    # アプリエントリーポイント
│   └── ZunTalkApp.swift
├── Config/                 # 設定
│   └── APIConfig.swift
├── Models/                 # データモデル
│   ├── Settings/
│   └── Errors/
├── Repository/             # データアクセス層
│   ├── TextGeneration/     # AI会話生成
│   ├── TextToSpeech/       # 音声合成
│   ├── SpeechRecognition/  # 音声認識
│   ├── AppInfo/            # アプリ情報
│   └── Keychain/           # 認証情報管理
└── Screens/                # 画面
    ├── Launch/             # 起動画面
    ├── Call/               # 通話画面
    ├── Config/             # 設定画面
    └── Onboarding/         # 初回起動画面
```

## 主要コンポーネント

### Repository層

#### TextGenerationRepository
AI会話生成を抽象化：
- OpenAI API呼び出し
- Foundation Models対応（iOS 26+）
- ファクトリーパターンで実装切り替え

#### TextToSpeechRepository
音声合成を抽象化：
- VOICEVOX Core統合
- バンドルから直接リソース読み込み
- 音声データ生成

#### SpeechRecognitionRepository
音声認識を抽象化：
- iOS Speech Framework統合
- リアルタイム認識
- 権限管理

### ViewModel層

#### CallViewModel
通話画面のビジネスロジック：
- 会話履歴管理
- 録音/再生制御
- リポジトリ調整

#### LaunchViewModel
起動画面のビジネスロジック：
- アプリ情報取得
- メンテナンスチェック
- バージョンチェック

## データフロー

### 会話生成フロー

```swift
// 1. ユーザー音声入力
SpeechRecognitionRepository
    → テキスト変換
    → ViewModel更新

// 2. AI応答生成
TextGenerationRepository
    → API呼び出し
    → 応答テキスト取得

// 3. 音声合成
TextToSpeechRepository
    → VOICEVOX Core
    → 音声データ生成

// 4. 再生
AVAudioPlayer
    → スピーカー出力
```

## 状態管理

### @Published プロパティ

ViewModelは`@Published`で状態を公開：

```swift
@Published var messages: [Message] = []
@Published var isRecording = false
@Published var audioData: Data?
```

Viewは自動的に更新されます。

## エラーハンドリング

各Repositoryは独自のError型を定義：

```
Repository/
  ├── TextGeneration/
  │   └── Error/
  │       ├── OpenAITextGenerationError.swift
  │       └── FoundationModelsTextGenerationError.swift
  ├── TextToSpeech/
  │   └── Error/
  │       └── VoicevoxError.swift
  └── SpeechRecognition/
      └── Error/
          └── SpeechRecognitionError.swift
```

## 非同期処理

Swift Concurrency (async/await) を使用：

```swift
func generateResponse() async {
    do {
        let response = try await repository.generate(messages)
        // 処理
    } catch {
        // エラー処理
    }
}
```

## テスト

### ユニットテスト
- Repository層のテスト
- ViewModel層のテスト
- Mock/Stubを使用

### UIテスト
- 画面遷移テスト
- API呼び出しスキップ（`SKIP-API-CALLS`フラグ）

## パフォーマンス最適化

### VOICEVOXリソース
- ✅ バンドルから直接読み込み
- ✅ フォルダ参照でディレクトリ構造保持
- ✅ 未使用モデル削除（228MB削減）

### メモリ管理
- weak/unowned参照で循環参照回避
- deinitでリソース解放

## セキュリティ

### Keychain
API Keyなどの機密情報をKeychainに保存：

```swift
KeychainRepository.save(key: "openai_api_key", value: apiKey)
```

### 権限管理
必要な権限のみリクエスト：
- マイク（音声認識）
- 音声認識（Speech Framework）

## 将来の拡張

- [ ] Core Data統合（会話履歴保存）
- [ ] Widget Extension
- [ ] Siri Shortcuts対応
- [ ] iCloud同期
