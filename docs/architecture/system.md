# システム構成

## 全体アーキテクチャ

バックエンドは用途別に2系統ある。

- **チャットAPI（AWS Lambda + OpenAI）**: 通常のAI会話生成
- **エージェント/電話予約（GCP Cloud Run + Vertex AI）**: エージェントモードの司令塔と、指定時刻の VoIP 着信

```
┌────────────────────────────────────────────────────────┐
│                        ユーザー                          │
└──────────────────────────┬─────────────────────────────┘
                           │
                  ┌────────▼────────┐
                  │    iOS App      │
                  │   (SwiftUI)     │
                  └─┬────┬────┬───┬─┘
       端末内で完結   │    │    │   │
  ┌─────────┐◄──────┘    │    │   └──────►┌──────────┐
  │ Speech  │ ┌──────────▼─┐  │           │ EventKit │
  │Framework│ │VOICEVOX Core│  │           │(カレンダー)│
  └─────────┘ └────────────┘  │           └──────────┘
                              │ HTTPS
              ┌───────────────┴───────────────┐
              ▼                               ▼
   ┌───────────────────┐          ┌─────────────────────────┐
   │   AWS Lambda      │          │   GCP Cloud Run         │
   │   (Go + Echo)     │          │   (Go + Echo)           │
   │   チャットAPI       │          │   エージェント + 電話予約   │
   └────────┬──────────┘          └──┬─────────┬─────────┬──┘
            ▼                        ▼         ▼         ▼
   ┌───────────────────┐    ┌──────────┐ ┌─────────┐ ┌───────────┐
   │   OpenAI API      │    │Vertex AI │ │Firestore│ │ Cloud     │
   │ (gpt-4o-mini/4o)  │    │ (Gemini) │ │         │ │ Scheduler │
   └───────────────────┘    └──────────┘ └─────────┘ └─────┬─────┘
                                                           │ 毎分
                                              APNs (VoIP push)──► iOS 着信
```

## コンポーネント詳細

### 1. iOSアプリケーション

#### 責務
- ユーザーインターフェース
- 音声入出力
- AI会話の管理

#### 技術スタック
- **言語**: Swift
- **UI**: SwiftUI
- **最小iOS**: 17.0
- **アーキテクチャ**: MVVM + Repository パターン

#### 主要モジュール
- `TextGenerationRepository`: AI会話生成
- `TextToSpeechRepository`: 音声合成
- `SpeechRecognitionRepository`: 音声認識
- `KeychainRepository`: 認証情報管理
- `AgentRepository` / `ToolExecutor`: エージェントの往復・端末ツール実行（EventKit カレンダー等）
- `CallScheduleRepository` / `VoIPPushManager` / `CallKitManager`: 電話予約と VoIP 着信

### 2. バックエンドAPI

#### 責務
- OpenAI APIとの通信
- リクエスト/レスポンスの変換
- エラーハンドリング

#### 技術スタック
- **言語**: Go 1.24
- **フレームワーク**: Echo v4
- **実行環境**: AWS Lambda + Lambda Web Adapter
- **デプロイ**: Docker + ECR

#### エンドポイント
- `POST /api/chat`: AI会話生成
- `GET /api/info`: アプリ情報取得
- `GET /health`: ヘルスチェック

### 3. エージェント / 電話予約バックエンド（GCP）

詳細は [agent/README.md](../../agent/README.md) を参照。

#### 責務
- **エージェントモード**: planner（Gemini）がユーザー発話から実行計画を立て、端末がツールを実行し、responder（Gemini）がずんだもん口調で応答を生成する（サーバーはオーケストレーション専任。ユーザーデータのツール実行は端末側）
- **電話予約**: Firestore に予約を保存し、Cloud Scheduler（毎分）→ `/internal/dispatch` → APNs VoIP push → iOS の PushKit/CallKit で着信（秒精度）

#### 技術スタック
- **言語**: Go 1.24 + Echo v4
- **実行環境**: Cloud Run（`zuntalk-agent-dev` / `zuntalk-agent-prod`）
- **AI**: Vertex AI（Gemini、ADC キーレス認証）
- **データストア**: Firestore（devices / scheduledCalls / agentUsage）。接続先DBは `FIRESTORE_DATABASE` で切り替え、dev は `(default)`・prod は `zuntalk-prod` でデータ分離

#### エンドポイント
- `POST /agent`: エージェント往復（X-Api-Key）
- `PUT /devices`, `POST/GET/DELETE /calls`: 電話予約（X-Api-Key）
- `POST /internal/dispatch`: Scheduler 専用（OIDC 検証）

#### ツール（capability）と EventKit
- 端末はリクエストで実行可能な capability を申告する（現状は `calendar` のみ）
- **カレンダーは EventKit で端末内の iOS 標準カレンダーを読む**（Google OAuth 審査が不要。Google アカウント同期済みの予定も読める）
- Gmail 連携は廃止済み（アプリからも planner の capability からも削除）

#### 利用回数制限
- deviceId ごとに `/agent` を日次 `AGENT_DAILY_LIMIT` 回（デフォルト50、JST 0時リセット）まで。超過は 429
- カウントは1巡目のみ・Firestore トランザクションで加算・障害時は許可に倒す（fail-open）
- カウンタは `expireAt` の TTL ポリシーで7日後に自動削除

### 4. インフラストラクチャ

#### AWS構成
- **Lambda**: サーバーレス実行環境
- **ECR**: Dockerイメージ管理
- **S3**: VOICEVOXリソース配信
- **IAM**: OIDC認証（GitHub Actions）

#### 環境分離
- **Shared** (448049807848): ECR、GitHub Actions IAM
- **Dev** (039612872248): 開発環境Lambda
- **Prod** (986921280333): 本番環境Lambda

- **Cloud Run**: エージェントサーバー実行環境（dev / prod の2サービス）
- **Vertex AI**: Gemini 呼び出し
- **Firestore**: 端末トークン・電話予約・利用回数カウンタ（TTL ポリシー含め Terraform 管理）。dev は `(default)` DB、prod は名前付きDB `zuntalk-prod` で**完全分離**。各環境が自分のDB・インデックス・TTL を所有し、将来 prod を別プロジェクト・別アカウントへ移せる構成
- **Cloud Scheduler**: 毎分のディスパッチ（OIDC 認証）。dev / prod それぞれが自分のDBの `scheduledCalls` を処理する
- **Secret Manager**: API キー・APNs Auth Key (.p8)
- **プロジェクト**: 現状は dev/prod とも sandbox-492513 内（`terraform/gcp/environments/{dev,prod}`）。Firestore はDBレベルで分離済みなので、prod のプロジェクト分割にコード変更なしで対応できる

## データフロー

### 会話フロー

1. **ユーザー音声入力**
   ```
   ユーザー → SpeechFramework → テキスト変換
   ```

2. **AI応答生成**
   ```
   テキスト → Lambda → OpenAI API → 応答テキスト
   ```

3. **音声合成**
   ```
   応答テキスト → VOICEVOX Core → 音声データ
   ```

4. **音声再生**
   ```
   音声データ → AVAudioPlayer → スピーカー
   ```

### エージェント会話フロー（2巡構造）

1. **1巡目（計画）**: 端末 → `POST /agent {message, capabilities, deviceId}` → planner（Gemini）が実行計画を返す（ツール不要なら即最終応答）
2. **端末ツール実行**: 計画の各ステップを端末で実行（calendar は EventKit で端末内カレンダーを読む）
3. **2巡目（応答）**: 端末 → `POST /agent {message, results}` → responder（Gemini）がずんだもん口調の返答と感情を返す → VOICEVOX で再生

### 電話予約フロー

1. アプリが VoIP トークンを `PUT /devices` で登録、`POST /calls` で予約作成（端末ごと1件まで）
2. Cloud Scheduler が毎分 `/internal/dispatch` を叩き、60秒先読みで対象を取得
3. 予約時刻ちょうどに Firestore で予約を claim → APNs へ VoIP push（秒精度・直前キャンセル可）
4. iOS が PushKit で受信 → CallKit のネイティブ着信 UI → 応答で会話開始

### VOICEVOXリソース配信フロー

```
開発時:
S3 → make setup-voicevox → ローカル

CI時:
S3 → GitHub Actions → Xcode Build → アプリバンドル
```

## セキュリティ

### 認証・認可
- **OpenAI API Key**: Keychainに安全に保存
- **Lambda URL**: パブリックアクセス（認証なし）
- **Cloud Run（/agent 等）**: 共有 `X-Api-Key`（Secret Manager 管理）+ deviceId ごとの日次利用回数制限
- **Cloud Run（/internal/dispatch）**: Cloud Scheduler の OIDC トークン検証（SA email + audience）
- **GitHub Actions**: OIDC認証（AWS / GCP Workload Identity Federation）
- **カレンダー**: EventKit で端末内読み取り（サーバーへは予定のタイトル・日時のみ送信。プラポリに明記）

### データ保護
- **通信**: HTTPS/TLS 1.2以上
- **ログ**: 個人情報は記録しない
- **キー管理**: iOS Keychain Services

## スケーラビリティ

### Lambda自動スケーリング
- リクエスト数に応じて自動スケール
- コールドスタート対策（最小実行時間確保）

### S3配信
- CloudFront連携可能
- 複数リージョン対応可能

## 監視・ログ

### CloudWatch
- Lambda実行ログ
- エラー率監視
- レスポンスタイム監視

### GitHub Actions
- CI/CDステータス
- デプロイ履歴

## パフォーマンス最適化

### iOS
- ✅ バンドルから直接読み込み（コピー不要）
- ✅ 未使用モデル削除（228MB削減）
- ✅ フォルダ参照でディレクトリ構造保持

### Lambda
- Docker Multi-stage build
- Lambda Web Adapter
- 環境変数キャッシュ

## 障害対策

### 可用性
- Lambda自動復旧
- S3の高可用性（99.99%）

### フェイルセーフ
- API呼び出し失敗時も動作継続
- オフライン対応（ローカルキャッシュ）
