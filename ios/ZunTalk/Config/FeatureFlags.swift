import Foundation

/// 機能の出し分けフラグ。
enum FeatureFlags {
    /// エージェント機能（3Dずんだもんとの会話）を有効にするか。
    /// カレンダーは EventKit を使うため、本番でも Google OAuth 審査なしで利用できる。
    static let agentModeEnabled = true

    /// 開発者向け UI（Gmail の Google 連携・エージェントテスト・表情確認）を有効にするか。
    /// Gmail は Google OAuth のテストモード運用（開発者アカウント専用）に留めるため Debug 限定にする。
    #if DEBUG
    static let debugToolsEnabled = true
    #else
    static let debugToolsEnabled = false
    #endif
}
